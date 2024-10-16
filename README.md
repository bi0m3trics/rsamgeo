
<!-- README.md is generated from README.Rmd. Please edit that file -->

# rsamgeo

The goal of {rsamgeo} is to provide a basic R wrapper around the
[`segment-geospatial`](https://github.com/opengeos/segment-geospatial)
‘Python’ package by [Dr. Qiusheng Wu](https://github.com/giswqs). Uses R
{reticulate} package to call tools for segmenting geospatial data with
the [Meta ‘Segment Anything Model’
(SAM)](https://github.com/facebookresearch/segment-anything). The
‘segment-geospatial’ package draws its inspiration from
‘segment-anything-eo’ repository authored by [Aliaksandr
Hancharenka](https://github.com/aliaksandr960) and the package [rsamgeo](https://github.com/brownag/rsamgeo)
by brownbag ([Andrew Gene Brown](https://github.com/brownag)).

## Setup
This initial R script uses the reticulate package to ensure that a specific
Python environment named 'myRSamGeo' is available and configured for use with
R. It checks if this conda environment already exists; if not, it creates the
environment and installs required Python packages, including samgeo and machine
learning libraries like PyTorch. 
If the environment exists, it activates it. 
Additionally, it checks whether the RETICULATE_PYTHON environment variable is
set, and if not, it sets this variable to point to the Python executable within
the myRSamGeo environment to ensure proper integration between R and Python.

``` r
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
                               "torchvision", "torchaudio", "pytorch-cuda=11.8",
                               "gdal"),
                channel = c("pytorch", "nvidia"))
} else {
  message("myRSamGeo environment already exists, so activating it...")
  use_condaenv("myRSamGeo", required = TRUE)
}

# Check if the RETICULATE_PYTHON environment variable is set
if (Sys.getenv("RETICULATE_PYTHON") == "") {
  # If not set, set the RETICULATE_PYTHON environment variable
  Sys.setenv(RETICULATE_PYTHON = "C:/ProgramData/anaconda3/python.exe")
  print("RETICULATE_PYTHON environment variable has been set.")
} else {
  print(paste("RETICULATE_PYTHON is already set to:", Sys.getenv("RETICULATE_PYTHON")))
}
```

## Installation

You can install the development version of {rsamgeo} like so:
``` r
# Ensure remotes package is installed
if (!require("remotes")) install.packages("remotes")

# Ensure terra package is installed
if (!require(terra)) install.packages("terra")
library(terra)

# Install the rsamgeo package from GitHub
remotes::install_github("bi0m3trics/rsamgeo")
rsamgeo::sg_install(conda = "C:/ProgramData/anaconda3/_conda.exe", system=TRUE)
```

## Example

After installing the package and the ‘Python’ dependencies, we can
setup an output directors and download some sample data using `tms_to_geotiff()`

``` r
library(reticulate)
use_condaenv("myRSamGeo", conda = "C:/ProgramData/anaconda3/_conda.exe", required = TRUE)
library(rsamgeo)

out_dir <- paste0(path.expand(file.path('~')), '/Downloads')
if (!dir.exists(out_dir)) {
  dir.create(out_dir)
}

sg <- samgeo()
sg$tms_to_geotiff(
  output = file.path(out_dir, "satellite.tif"),
  bbox = c(-111.62367, 35.22365, -111.62103, 35.22615),
  zoom = 20L,                                                   # https://wiki.openstreetmap.org/wiki/Zoom_levels
  source = 'Satellite',
  overwrite = TRUE
)
```

The SAM `model_type` specifies the SAM model you wish to use with
the neccessary parameetrs (see <a href = "https://samgeo.gishub.org/samgeo/?h=batch#samgeo.samgeo.SamGeo.generate">here</a> for detailes) . Trained model data used for segmentation are downloaded if the file `checkpoint`
is not found. Downloading this for the first time may take a while.
Create an instance of your desired model with `sg_samgeo()`

``` r
checkpoint <- file.path(out_dir, 'sam_vit_h_4b8939.pth')

# https://samgeo.gishub.org/samgeo/#samgeo.samgeo
sam <- sg_samgeo(
  model_type = 'vit_h',
  checkpoint = checkpoint,
  erosion_kernel = c(3L, 3L),
  mask_multiplier = 255L,
  sam_kwargs = NULL
)
```

Finally, generate a segmented image from the input, processing the input
in chunks as needed with `batch=TRUE`. Note that you want this
processing to run on the GPU with CUDA enabled. For the [Google Colab
Notebook]((https://colab.research.google.com/drive/1DwHUc1Vpgg1dRTSKB7AY5puDM_2uB8MY?usp=sharing))
example remember to set the notebook runtime to ‘GPU’.

``` r
# https://samgeo.gishub.org/samgeo/#samgeo.samgeo.SamGeo.generate
sg_generate(sam, source = file.path(out_dir, 'satellite.tif'), 
            output = file.path(out_dir, 'segment.tif'),
            batch = TRUE, batch_sample_size = c(300L, 300L))
```

Now that we have processed the input data, we can convert the segmented
image to vectors and write them out as a layer in a shapefile for
subsequent use.

``` r
# https://samgeo.gishub.org/samgeo/#samgeo.samgeo.SamGeo.tiff_to_shp
sam$tiff_to_shp(tiff_path = file.path(out_dir, 'segment.tif'),
                output = file.path(out_dir, 'segment.shp'),
                simplify_tolerance=NULL)
```

It is then fairly easy to overlay our segment polygons on the original
satellite image with {terra}:

``` r
library(terra)
r <- rast(file.path(out_dir, 'satellite.tif'))
v <- vect(file.path(out_dir, 'segment.shp'))
v$ID <- seq_len(nrow(v))
plotRGB(r)
plot(v, col = v$ID, alpha = 0.25, add = TRUE)
```
![image](https://github.com/user-attachments/assets/41708471-588a-4e4a-801f-52c34ea148c8)


