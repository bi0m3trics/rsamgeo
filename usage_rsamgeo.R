# Ensure reticulate package is installed
if (!require(reticulate)) install.packages("reticulate")
library(reticulate)

# Verify the installation of samgeo
installed_packages <- conda_list()

# Check if 'myRSamGeo' is in the list of installed packages
if (!"myRSamGeo" %in% installed_packages$name) {
  # Create the conda environment
  conda_create("myRSamGeo")
  # Install necessary Python packages in the new environment
  conda_install("myRSamGeo", c("samgeo", "segment-geospatial", "pytorch",
                               "torchvision", "torchaudio", "pytorch-cuda=11.8"),
                channel = c("pytorch", "nvidia"))
} else {
  message("myRSamGeo environment already exists, so activating it...")
  use_condaenv("myRSamGeo", required = TRUE)
}

# Check if the RETICULATE_PYTHON environment variable is set
if (Sys.getenv("RETICULATE_PYTHON") == "") {
  # If not set, set the RETICULATE_PYTHON environment variable
  Sys.setenv(RETICULATE_PYTHON = "C:/Users/ajsm/.conda/envs/myRSamGeo/python.exe")
  print("RETICULATE_PYTHON environment variable has been set.")
} else {
  print(paste("RETICULATE_PYTHON is already set to:", Sys.getenv("RETICULATE_PYTHON")))
}

# ------------------------------------------------------------------------------

# Ensure remotes package is installed
# if (!require("remotes")) install.packages("remotes")

# Ensure terra package is installed
# if (!require(terra)) install.packages("terra")
library(terra)

# Install the rsamgeo package from GitHub
# if (!require("rsamgeo")) remotes::install_github("bi0m3trics/rsamgeo")
library(rsamgeo)

# Example usage of rsamgeo
out_dir <- "C:/Users/ajsm/Desktop/myRSamGeo/"

sg <- samgeo()
sg$tms_to_geotiff(
  output = paste0(out_dir, "satellite.tif"),
  bbox = c(-111.62367, 35.22365, -111.62103, 35.22615),
  zoom = 20L,                                                   # https://wiki.openstreetmap.org/wiki/Zoom_levels
  source = 'Satellite',
  overwrite = TRUE
)

checkpoint <- paste0(out_dir, 'sam_vit_h_4b8939.pth')

sam <- sg_samgeo(                                               # https://samgeo.gishub.org/samgeo/?h=batch#samgeo.samgeo.SamGeo.generate
  model_type = 'vit_h',
  checkpoint = checkpoint,
  # foreground=TRUE,
  batch=TRUE,
  # batch_sample_size=c(512L, 512L),
  erosion_kernel = c(3L, 3L),
  mask_multiplier = 255L,
  # unique=TRUE,
  sam_kwargs = NULL
)

sg_generate(sam, source = paste0(out_dir, 'satellite.tif'), output = paste0(out_dir, 'segment.tif'))

sam$tiff_to_gpkg(paste0(out_dir, 'segment.tif'), paste0(out_dir, 'segment.gpkg'), simplify_tolerance=NULL)

v <- vect(paste0(out_dir, 'segment.gpkg'))
v$ID <- seq_len(nrow(v))

r <- rast(paste0(out_dir, 'satellite.tif'))
plotRGB(r)
plot(v, col = v$ID, alpha = 0.25, add = TRUE)

terra::writeVector(v, paste0(out_dir, 'sam_vect.shp'), filetype = "ESRI Shapefile", overwrite=TRUE)
