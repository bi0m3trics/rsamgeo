# =============================================================================
# INIT_SESSION.R - Source this at the start of each R session
# =============================================================================
# Usage: source("init_session.R")
#
# This script:
# 1. Clears any previous Python configuration
# 2. Sets the myRSamGeo conda environment
# 3. Verifies the configuration
# 4. Loads required packages in the correct order
# =============================================================================

message("=" , rep("=", 78), "=")
message("Initializing R session for rsamgeo...")
message("=" , rep("=", 78), "=")

# Clear any previous Python settings
Sys.setenv(RETICULATE_PYTHON = "")

# Load reticulate FIRST
if (!require(reticulate, quietly = TRUE)) {
  message("Installing reticulate...")
  install.packages("reticulate")
  library(reticulate)
}

# Set conda environment BEFORE any Python initialization
message("\n[1/4] Setting Python environment...")
tryCatch({
  use_condaenv("myRSamGeo", required = TRUE)
  message("      ✓ myRSamGeo environment set")
}, error = function(e) {
  message("      ✗ Error: ", e$message)
  message("\n      Have you created the environment? Run:")
  message("      conda_create('myRSamGeo', python_version = '3.9')")
  message("      conda_install('myRSamGeo', c('samgeo', 'segment-geospatial', 'pytorch'))")
  stop("Environment setup failed")
})

# Verify Python configuration
message("\n[2/4] Verifying Python configuration...")
py_cfg <- py_discover_config()
message("      Python: ", py_cfg$python)
message("      Version: ", py_cfg$version)

if (!grepl("myRSamGeo", py_cfg$python)) {
  warning("      ⚠ Warning: Python path doesn't contain 'myRSamGeo'")
  warning("      You may need to restart R and try again")
}

# Load required R packages
message("\n[3/4] Loading R packages...")

packages <- c("terra", "sf", "rstac", "copc4R")
for (pkg in packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    message("      Installing ", pkg, "...")
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}
message("      ✓ R packages loaded")

# Load rsamgeo (this will initialize Python)
message("\n[4/4] Loading rsamgeo...")
if (!require(rsamgeo, quietly = TRUE)) {
  message("      Installing rsamgeo from GitHub...")
  if (!require(remotes)) install.packages("remotes")
  remotes::install_github("bi0m3trics/rsamgeo")
  library(rsamgeo)
}

# Verify rsamgeo is working
tryCatch({
  sg_ver <- sg_version()
  cuda_avail <- sg_torch_cuda_is_available()
  message("      ✓ rsamgeo loaded successfully")
  message("      samgeo version: ", sg_ver)
  message("      CUDA available: ", cuda_avail)
}, error = function(e) {
  message("      ✗ Error loading rsamgeo: ", e$message)
})

message("\n" , rep("=", 80))
message("✓ Session initialized successfully!")
message("  Ready to run rsamgeo workflows")
message(rep("=", 80), "\n")

# Clean up
rm(packages, pkg, py_cfg, sg_ver, cuda_avail)
