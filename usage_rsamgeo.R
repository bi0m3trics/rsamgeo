# =============================================================================
# ENVIRONMENT SETUP - MUST BE FIRST!
# =============================================================================
# IMPORTANT: This must run BEFORE loading any packages that use Python
# If you get "another version of Python has already been initialized" error,
# restart R session (Ctrl+Shift+F10 in RStudio) and run this section first.
#
# ALTERNATIVE: Instead of running this manually, you can:
#   source("init_session.R")
# which handles everything automatically in the correct order.
# =============================================================================

# Ensure reticulate package is installed
if (!require(reticulate, quietly = TRUE)) install.packages("reticulate")

# Set Python environment BEFORE loading reticulate or any Python-dependent packages
Sys.setenv(RETICULATE_PYTHON = "")  # Clear any previous setting

# Use the conda environment (this must happen BEFORE loading rsamgeo)
reticulate::use_condaenv("myRSamGeo", required = TRUE)

# Setup conda environment function (only run if environment doesn't exist)
setup_environment <- function() {
  library(reticulate)
  installed_packages <- conda_list()

  if (!"myRSamGeo" %in% installed_packages$name) {
    message("Creating myRSamGeo conda environment...")
    conda_create("myRSamGeo", python_version = "3.9")
    conda_install("myRSamGeo",
                  c("samgeo", "segment-geospatial", "pytorch",
                    "torchvision", "torchaudio", "pytorch-cuda=11.8"),
                  channel = c("pytorch", "nvidia"))
    message("\n*** RESTART R SESSION after environment creation ***\n")
  } else {
    message("myRSamGeo environment exists.")
  }
}

# Uncomment ONLY if you need to create the environment for the first time:
# setup_environment()
# # Then RESTART R and run the rest of the script

# Verify Python configuration (optional but recommended)
message("Python configuration:")
py_config <- reticulate::py_discover_config()
message("  Python: ", py_config$python)
message("  Version: ", py_config$version)

# =============================================================================
# LOAD PACKAGES
# =============================================================================

if (!require(terra)) install.packages("terra")
if (!require(sf)) install.packages("sf")
if (!require(rstac)) install.packages("rstac")
if (!require(copc4R)) install.packages("copc4R")

library(terra)
library(sf)
library(rstac)
library(copc4R)

# Load rsamgeo package (this will initialize Python with the conda env set above)
# if (!require("rsamgeo")) remotes::install_github("bi0m3trics/rsamgeo")
library(rsamgeo)

# Check if samgeo is installed in Python environment
samgeo_installed <- tryCatch({
  sg_test <- samgeo()
  TRUE
}, error = function(e) {
  if (grepl("not found", e$message, ignore.case = TRUE)) {
    message("\n⚠ samgeo Python module not found in conda environment")
    message("Installing samgeo and dependencies...")

    # Install using conda
    reticulate::conda_install(
      envname = "myRSamGeo",
      packages = c("samgeo", "segment-geospatial"),
      pip = TRUE
    )

    message("✓ Installation complete. Please restart R and run the script again.")
    return(FALSE)
  }
  stop(e)
})

if (!samgeo_installed) {
  stop("samgeo was just installed. Please restart R session and run the script again.")
}

# Verify CUDA availability (optional but recommended)
if (sg_torch_cuda_is_available()) {
  message("CUDA is available - using GPU acceleration")
} else {
  message("CUDA not available - using CPU (this will be slower)")
}

# =============================================================================
# ACQUIRE IMAGERY FROM PLANETARY COMPUTER (NAIP)
# =============================================================================

# Set output directory
out_dir <- "C:/Users/ajsm/Desktop/myRSamGeo/"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# Draw area of interest
message("Draw your area of interest...")
aoi <- copc4R::get_aoi()
if (is.null(aoi)) stop("No AOI drawn.")

# Keep AOI in lon/lat (EPSG:4326) for STAC search
aoi <- sf::st_transform(aoi, 4326)

# Connect to Microsoft Planetary Computer STAC API
message("Connecting to Planetary Computer STAC API...")
stac_obj <- rstac::stac("https://planetarycomputer.microsoft.com/api/stac/v1")

# Create bounding box for STAC search
bb <- sf::st_bbox(aoi)
bbox_vec <- c(
  unname(bb["xmin"]),
  unname(bb["ymin"]),
  unname(bb["xmax"]),
  unname(bb["ymax"])
)

# Search for NAIP imagery
message("Searching for NAIP imagery...")
items <- stac_obj |>
  rstac::stac_search(
    collections = "naip",
    bbox = bbox_vec,
    limit = 100
  ) |>
  rstac::post_request()

# Sign the items for access
items <- rstac::items_sign_planetary_computer(items)

if (length(items$features) == 0) {
  stop("No NAIP imagery found for AOI.")
}

message("Found ", length(items$features), " NAIP images")

# Choose the most recent item
item_dates <- vapply(
  items$features,
  function(x) {
    d <- x$properties$datetime
    if (is.null(d)) d <- NA_character_
    d
  },
  character(1)
)

item <- items$features[[order(as.POSIXct(item_dates), decreasing = TRUE)[1]]]
href <- item$assets$image$href

message("Using most recent imagery from: ", item$properties$datetime)

# Configure GDAL for cloud-optimized GeoTIFF access
Sys.setenv(
  GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR",
  CPL_VSIL_CURL_USE_HEAD = "NO"
)

# Load raster from cloud
message("Loading imagery from cloud...")
r <- terra::rast(paste0("/vsicurl/", href))

# Project AOI with sf, then convert to terra
aoi_r <- sf::st_transform(aoi, terra::crs(r))
aoi_v <- terra::vect(aoi_r)

# Crop by extent only
message("Cropping to area of interest...")
e <- terra::ext(aoi_v)
rc <- terra::crop(r, e, snap = "out")
rc <- terra::mask(rc, aoi_v)

# Preview the imagery
terra::plotRGB(rc, r = 1, g = 2, b = 3, stretch = "lin",
               main = "Source Imagery for Segmentation")

# Check image properties before saving
message("Image bands: ", nlyr(rc))
message("Image datatype: ", datatype(rc))
message("Image range: [", min(values(rc), na.rm = TRUE), ", ",
        max(values(rc), na.rm = TRUE), "]")

# If image has 4 bands (RGBNIR), keep only NIRRG for SAM
if (nlyr(rc) == 4) {
  message("NAIP has 4 bands (RGBNIR). Keeping only RGB (bands 4,1,2) for segmentation...")
  rc <- rc[[c(1,2,3)]]
}

# Ensure values are in 0-255 range for 8-bit RGB
rc_min <- min(values(rc), na.rm = TRUE)
rc_max <- max(values(rc), na.rm = TRUE)

if (rc_max <= 1) {
  message("Scaling values from [0,1] to [0,255]...")
  rc <- rc * 255
} else if (rc_max > 255) {
  message("Rescaling values to [0,255]...")
  rc <- (rc / rc_max) * 255
}

# Save to file for SAM processing
satellite_tif <- paste0(out_dir, "satellite.tif")
message("Saving imagery to: ", satellite_tif)

# Save with specific options for compatibility with OpenCV/SAM
terra::writeRaster(
  rc,
  satellite_tif,
  overwrite = TRUE,
  gdal = c("COMPRESS=LZW", "TILED=YES"),
  datatype = "INT1U"  # Ensure 8-bit unsigned integer for RGB
)

# Verify the file was created and is valid
if (!file.exists(satellite_tif)) {
  stop("Failed to create satellite imagery file")
}
file_size <- file.size(satellite_tif) / 1024^2  # Size in MB
message("Satellite imagery saved (", round(file_size, 2), " MB)")
message("Image dimensions: ", paste(dim(rc)[2:1], collapse = " x "), " pixels")

# =============================================================================
# INITIALIZE SAM MODEL
# =============================================================================

# Initialize samgeo module
sg <- samgeo()

# Set checkpoint path (SAM will auto-download if not present)
checkpoint <- paste0(out_dir, 'sam_vit_h_4b8939.pth')

# Initialize SAM model with improved parameters for better segmentation
message("Initializing SAM model...")
sam <- sg_samgeo(
  model_type = 'vit_h',
  checkpoint = checkpoint,
  automatic = TRUE,
  sam_kwargs = list(
    points_per_side = 32L,              # Default value
    pred_iou_thresh = 0.7,
    stability_score_thresh = 0.95,
    crop_n_layers = 1L,
    min_mask_region_area = 200L
  )
)

# =============================================================================
# GENERATE SEGMENTATION
# =============================================================================

# Generate segmentation
message("Generating segmentation (this may take a few minutes)...")

# Verify input file exists before processing
if (!file.exists(satellite_tif)) {
  stop("Input imagery file not found: ", satellite_tif)
}

# Run segmentation - use normalized path separators
sg_generate(
  sam,
  source = normalizePath(satellite_tif, winslash = "/"),
  output = normalizePath(paste0(out_dir, 'segment.tif'), winslash = "/", mustWork = FALSE)
)

# Convert segmentation to GeoPackage
message("Converting to vector format...")
sam$tiff_to_gpkg(
  paste0(out_dir, 'segment.tif'),
  paste0(out_dir, 'segment.gpkg'),
  simplify_tolerance = NULL
)

# =============================================================================
# VISUALIZATION
# =============================================================================

# Load and prepare vectors
v <- vect(paste0(out_dir, 'segment.gpkg'))
v$ID <- seq_len(nrow(v))

message("Segmented ", nrow(v), " features")

# Load raster
r_vis <- rast(satellite_tif)

# Plot results
par(mfrow = c(1, 2), mar = c(2, 2, 3, 2))

# Plot 1: Original imagery
plotRGB(r_vis, r = 1, g = 2, b = 3, stretch = "lin", main = "Original NAIP Imagery")

# Plot 2: Segmentation overlay
plotRGB(r_vis, r = 1, g = 2, b = 3, stretch = "lin",
        main = paste("Segmentation:", nrow(v), "features"))
plot(v, col = lidR::random.colors(nrow(v)), alpha = 0.7, add = TRUE, border = "black")

# Export to shapefile
terra::writeVector(
  v,
  paste0(out_dir, 'sam_vect.shp'),
  filetype = "ESRI Shapefile",
  overwrite = TRUE
)

message("Segmentation complete! Files saved to: ", out_dir)

# =============================================================================
# OPTIONAL: Clear CUDA cache to free memory
# =============================================================================
if (sg_torch_cuda_is_available()) {
  sg_clear_cuda_cache()
}
