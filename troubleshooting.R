# =============================================================================
# TROUBLESHOOTING GUIDE FOR RSAMGEO
# =============================================================================

# -----------------------------------------------------------------------------
# PROBLEM 1: Poor Segmentation Quality (Too Many or Too Few Segments)
# -----------------------------------------------------------------------------

# Symptoms:
# - Too many tiny segments
# - Objects not properly separated
# - Important features missed

# Solutions:

# A) Too many small segments - Increase filtering:
sam <- sg_samgeo(
  model_type = 'vit_h',
  checkpoint = checkpoint,
  automatic = TRUE,
  sam_kwargs = list(
    points_per_side = 32L,
    pred_iou_thresh = 0.92,              # Increase from 0.88 (stricter)
    stability_score_thresh = 0.96,       # Increase from 0.95 (stricter)
    min_mask_region_area = 500L          # Add or increase to filter small areas
  )
)

# B) Missing features - Increase sampling:
sam <- sg_samgeo(
  model_type = 'vit_h',
  checkpoint = checkpoint,
  automatic = TRUE,
  sam_kwargs = list(
    points_per_side = 48L,               # Increase from 32
    pred_iou_thresh = 0.86,              # Decrease (more permissive)
    stability_score_thresh = 0.92,       # Decrease (more permissive)
    min_mask_region_area = 100L          # Lower threshold
  )
)

# -----------------------------------------------------------------------------
# PROBLEM 2: Out of Memory Errors
# -----------------------------------------------------------------------------

# Symptoms:
# - "CUDA out of memory" error
# - R crashes during segmentation

# Solutions:

# A) Clear CUDA cache before running:
sg_clear_cuda_cache()

# B) Use smaller model:
sam <- sg_samgeo(
  model_type = 'vit_l',                  # or 'vit_b'
  checkpoint = 'sam_vit_l_0b3195.pth',
  automatic = TRUE
)

# C) Reduce points_per_side:
sam <- sg_samgeo(
  model_type = 'vit_h',
  checkpoint = checkpoint,
  automatic = TRUE,
  sam_kwargs = list(
    points_per_side = 16L                # Reduce from 32
  )
)

# D) Process smaller images or tiles
# Crop your input image before processing

# -----------------------------------------------------------------------------
# PROBLEM 3: Slow Processing Speed
# -----------------------------------------------------------------------------

# Symptoms:
# - Segmentation takes hours
# - Not using GPU acceleration

# Solutions:

# A) Verify CUDA is being used:
if (sg_torch_cuda_is_available()) {
  message("GPU available")
} else {
  message("Using CPU - this will be VERY slow")
  message("Install CUDA-enabled PyTorch for GPU acceleration")
}

# B) Use faster configuration:
sam <- sg_samgeo(
  model_type = 'vit_l',                  # Smaller model
  checkpoint = 'sam_vit_l_0b3195.pth',
  automatic = TRUE,
  sam_kwargs = list(
    points_per_side = 16L,               # Fewer points
    min_mask_region_area = 500L          # Filter more aggressively
  )
)

# C) Use lower resolution imagery:
# In tms_to_geotiff, reduce zoom level:
sg$tms_to_geotiff(
  output = "satellite.tif",
  bbox = bbox,
  zoom = 18L,                            # Lower from 20L
  source = 'Satellite',
  overwrite = TRUE
)

# -----------------------------------------------------------------------------
# PROBLEM 4: Python/Reticulate Configuration Issues
# -----------------------------------------------------------------------------

# Symptoms:
# - "Python not found" errors
# - "Module 'samgeo' not found"
# - Environment not loading correctly

# Solutions:

# A) Explicitly set Python environment:
library(reticulate)
use_condaenv("myRSamGeo", required = TRUE)

# B) Check what Python is being used:
py_config()

# C) Reinstall in correct environment:
conda_install("myRSamGeo", 
              c("samgeo", "segment-geospatial"),
              pip = TRUE)

# D) Start fresh R session:
# Sometimes reticulate locks to the first Python it finds.
# Restart R and set environment BEFORE loading any packages.

# -----------------------------------------------------------------------------
# PROBLEM 5: Checkpoint File Download Issues
# -----------------------------------------------------------------------------

# Symptoms:
# - Model checkpoint not found
# - Download errors

# Solutions:

# A) Download checkpoint manually:
# Visit: https://github.com/facebookresearch/segment-anything#model-checkpoints
# Download to your out_dir and specify path:
checkpoint <- "C:/full/path/to/sam_vit_h_4b8939.pth"

# B) Let samgeo auto-download (default behavior):
sam <- sg_samgeo(
  model_type = 'vit_h',
  checkpoint = NULL,                     # Will auto-download
  automatic = TRUE
)

# -----------------------------------------------------------------------------
# PROBLEM 6: Vector Conversion Errors
# -----------------------------------------------------------------------------

# Symptoms:
# - tiff_to_gpkg fails
# - No features in output

# Solutions:

# A) Check if segmentation produced output:
file.exists(paste0(out_dir, 'segment.tif'))
r <- rast(paste0(out_dir, 'segment.tif'))
print(r)
unique(values(r))  # Should have multiple values

# B) Try different simplification:
sam$tiff_to_gpkg(
  'segment.tif', 
  'segment.gpkg', 
  simplify_tolerance = 0.5              # Add some simplification
)

# C) Use different output format:
sam$tiff_to_shp('segment.tif', 'segment.shp')

# -----------------------------------------------------------------------------
# DEBUGGING WORKFLOW
# -----------------------------------------------------------------------------

# 1. Test with very small area first:
sg$tms_to_geotiff(
  output = "test.tif",
  bbox = c(lon_min, lat_min, lon_min + 0.001, lat_min + 0.001),  # Tiny area
  zoom = 18L,
  source = 'Satellite',
  overwrite = TRUE
)

# 2. Use fastest configuration:
sam <- sg_samgeo(
  model_type = 'vit_l',
  checkpoint = NULL,
  automatic = TRUE,
  sam_kwargs = list(points_per_side = 16L)
)

# 3. Test generation:
sg_generate(sam, source = "test.tif", output = "test_seg.tif")

# 4. If successful, scale up gradually

# =============================================================================
