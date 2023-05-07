
<!-- README.md is generated from README.Rmd. Please edit that file -->

# {rsamgeo}

<!-- badges: start -->
<!-- badges: end -->

The goal of {rsamgeo} is to provide a basic R wrapper around the
‘`segment-geospatial`’ ‘Python’ package

## Installation

You can install the development version of {rsamgeo} like so:

``` r
remotes::install_github("brownag/rsamgeo")
```

## Example

This is a basic example which shows you how to solve a common problem:

``` r
library(rsamgeo)

samgeo()$tms_to_geotiff(
  output = "satellite.tif",
  bbox = c(-120.3704, 37.6762, -120.368, 37.6775),
  zoom = 20L,
  source = 'Satellite',
  overwrite = TRUE
)

out_dir <- path.expand(file.path('~', 'Downloads'))
checkpoint <- file.path(out_dir, 'sam_vit_h_4b8939.pth')

sam <- sg_samgeo(
  model_type = 'vit_h',
  checkpoint = checkpoint,
  erosion_kernel = c(3L, 3L),
  mask_multiplier = 255L,
  sam_kwargs = NULL
)

sg_generate(sam, "satellite.tif", "segment.tif", batch = TRUE)
```

``` r
library(terra)
r <- rast("satellite.tif")
plotRGB(r)
plot(v, col = v$ID, alpha = 0.25, add = TRUE)
```
