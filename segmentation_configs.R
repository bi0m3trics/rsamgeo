# =============================================================================
# ALTERNATIVE SEGMENTATION CONFIGURATIONS
# =============================================================================
# 
# This file contains various configuration examples for different segmentation
# scenarios. Copy the relevant configuration to your main script.
#
# =============================================================================

library(rsamgeo)

# -----------------------------------------------------------------------------
# CONFIG 1: High-Quality Segmentation (Slow, Many Objects)
# -----------------------------------------------------------------------------
# Use this for detailed segmentation of complex scenes
# Best for: Urban areas, forests, agricultural fields with many small objects

sam_high_quality <- sg_samgeo(
  model_type = 'vit_h',
  checkpoint = checkpoint,
  automatic = TRUE,
  sam_kwargs = list(
    points_per_side = 64L,              # More sampling points (32-64 typical)
    pred_iou_thresh = 0.92,             # Higher quality threshold
    stability_score_thresh = 0.96,      # More stable masks only
    box_nms_thresh = 0.75,              # Non-maximum suppression threshold
    crop_n_layers = 1L,                 
    crop_nms_thresh = 0.7,
    min_mask_region_area = 100L         # Filter out tiny objects
  )
)

# -----------------------------------------------------------------------------
# CONFIG 2: Fast Segmentation (Fewer, Larger Objects)
# -----------------------------------------------------------------------------
# Use this for quicker processing with larger features
# Best for: Large buildings, water bodies, major land use categories

sam_fast <- sg_samgeo(
  model_type = 'vit_h',
  checkpoint = checkpoint,
  automatic = TRUE,
  sam_kwargs = list(
    points_per_side = 16L,              # Fewer sampling points = faster
    pred_iou_thresh = 0.86,
    stability_score_thresh = 0.92,
    min_mask_region_area = 500L         # Ignore smaller objects
  )
)

# -----------------------------------------------------------------------------
# CONFIG 3: Balanced Configuration (Recommended Starting Point)
# -----------------------------------------------------------------------------
# Good balance between speed and quality
# Best for: General purpose segmentation

sam_balanced <- sg_samgeo(
  model_type = 'vit_h',
  checkpoint = checkpoint,
  automatic = TRUE,
  sam_kwargs = list(
    points_per_side = 32L,              # Default value
    pred_iou_thresh = 0.88,
    stability_score_thresh = 0.95,
    crop_n_layers = 1L,
    min_mask_region_area = 200L
  )
)

# -----------------------------------------------------------------------------
# CONFIG 4: Interactive/Prompted Segmentation (With Bounding Box or Points)
# -----------------------------------------------------------------------------
# Use this when you want to segment specific objects by providing:
# - Bounding boxes around objects of interest
# - Point prompts (foreground/background points)
# Best for: Targeting specific features

sam_interactive <- sg_samgeo(
  model_type = 'vit_h',
  checkpoint = checkpoint,
  automatic = FALSE,                    # Not automatic - needs prompts
  # Then use sam$predict() with boxes or points
)

# Example usage with boxes:
# boxes <- list(c(xmin, ymin, xmax, ymax))  # In pixel coordinates
# sam_interactive$predict(source = "image.tif", boxes = boxes)

# Example usage with points:
# point_coords <- list(c(x, y))
# point_labels <- list(1L)  # 1 = foreground, 0 = background
# sam_interactive$predict(source = "image.tif", 
#                        point_coords = point_coords,
#                        point_labels = point_labels)

# -----------------------------------------------------------------------------
# CONFIG 5: For Smaller Model (Faster, Less Memory)
# -----------------------------------------------------------------------------
# Use vit_l or vit_b for faster processing with less accurate results
# Best for: Quick tests, limited GPU memory, or rapid prototyping

sam_small_model <- sg_samgeo(
  model_type = 'vit_l',                 # or 'vit_b' for smallest
  checkpoint = 'sam_vit_l_0b3195.pth',  # Match model type
  automatic = TRUE,
  sam_kwargs = list(
    points_per_side = 32L,
    pred_iou_thresh = 0.86,
    stability_score_thresh = 0.92
  )
)

# =============================================================================
# KEY PARAMETERS EXPLAINED
# =============================================================================
#
# model_type: 
#   - 'vit_h': Largest, most accurate (default)
#   - 'vit_l': Medium size
#   - 'vit_b': Smallest, fastest
#
# automatic: 
#   - TRUE: Generate masks automatically across the entire image
#   - FALSE: Requires point/box prompts for specific objects
#
# points_per_side:
#   - Number of sampling points along each axis (default: 32)
#   - Higher = more detailed but slower (16-64 typical range)
#
# pred_iou_thresh:
#   - Predicted IoU threshold for keeping masks (0-1)
#   - Higher = only keep high-quality masks (default: 0.88)
#
# stability_score_thresh:
#   - Stability score threshold (0-1)
#   - Higher = only keep stable masks (default: 0.95)
#
# min_mask_region_area:
#   - Minimum area in pixels for a mask to be kept
#   - Higher = filter out smaller objects
#
# crop_n_layers:
#   - Number of crop layers for processing large images
#   - 0 = no crops, 1+ = process in overlapping crops
#
# =============================================================================
