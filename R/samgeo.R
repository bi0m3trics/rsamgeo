#' `sg_version()`: Gets the `segment-geospatial` version
#' @rdname samgeo
#' @return character. Version Number.
#' @export
#' @importFrom reticulate py_eval
sg_version <- function() {
  sg <- samgeo()
  return(sg[["__version__"]])
}

#' `Module(samgeo)` - Create `samgeo` Model Instance
#'
#' Gets the `samgeo` module instance in use by the package in current **R**/`reticulate` session.
#' @export
#'
samgeo <- function() {
  reticulate::import("samgeo")
}

#' @param ... Arguments to create model instance
#' @return `sg_samgeo()`: return `SamGeo` model instance
#' @export
#' @rdname samgeo
sg_samgeo <- function(...) {
  sg$SamGeo(...)
}

#' Generate SamGeo Model Segmentation Output
#'
#' Create segmented image based on input GeoTIFF.
#'
#' @param x A `SamGeo` model instance
#' @param ... Arguments to `SamGeo.generate()`
#' @export
sg_generate <- function(x, ...) {
  stopifnot(inherits(x, 'samgeo.samgeo.SamGeo'))
  x$generate(...)
}

#' Get `Module(torch)` Instance Used By `Module(samgeo)`
#'
#' @return `Module(torch)` instance from `Module(`
#'
#' @export
sg_torch <- function() {
  reticulate::import("torch")
}

#'
#' @return `sg_torch_cuda_is_available()`: `logical`. Is CUDA available?
#'
#' @rdname sg_torch
#' @export
sg_torch_cuda_is_available <- function() {
  sg <- sg_torch()
  cuda_available <- sg$torch$cuda$is_available()
  return(cuda_available)
}

#'
#' @return `sg_clear_cuda_cache()` Clears the CUDA cache.
#'
#' @rdname sg_torch
#' @export
sg_clear_cuda_cache <- function() {
  sg <- sg_torch()
  sg$torch$cuda$empty_cache()
}
