# Setup Instructions for rsamgeo

## The Problem

Reticulate (the R-Python bridge) locks to the **first** Python environment it finds in an R session. Once locked, you **cannot** change it without restarting R.

## Solution: Proper Startup Order

### Step 1: Create Environment (First Time Only)

If you haven't created the `myRSamGeo` conda environment yet, run this in a **fresh R session**:

```r
library(reticulate)

# Create environment
conda_create("myRSamGeo", python_version = "3.9")

# Install packages
conda_install("myRSamGeo", 
              c("samgeo", "segment-geospatial", "pytorch",
                "torchvision", "torchaudio", "pytorch-cuda=11.8"),
              channel = c("pytorch", "nvidia"))
```

After creation, **restart R** before proceeding.

### Step 2: Set Environment FIRST (Every Session)

In a **fresh R session**, run this **BEFORE** loading any other packages:

```r
# Clear any previous Python settings
Sys.setenv(RETICULATE_PYTHON = "")

# Set the conda environment (do this FIRST!)
library(reticulate)
use_condaenv("myRSamGeo", required = TRUE)

# Verify it worked
py_config()
```

You should see output showing the Python path points to `myRSamGeo`.

### Step 3: Now Load Other Packages

Only after Step 2, load your other packages:

```r
library(terra)
library(sf)
library(rstac)
library(copc4R)
library(rsamgeo)  # This will initialize Python with the conda env
```

## Common Errors and Fixes

### Error: "another version of Python has already been initialized"

**Cause**: You loaded a package that uses Python (like `rsamgeo`) before setting the environment.

**Fix**: 
1. Restart R session (Ctrl+Shift+F10 in RStudio, or Session → Restart R)
2. Run Step 2 FIRST
3. Then load other packages

### Error: "failed to initialize requested version of Python"

**Cause**: Same as above - wrong Python was locked in.

**Fix**: Restart R and follow the proper order.

## Quick Start Checklist

For each new R session:

- [ ] Start fresh R session (restart if needed)
- [ ] Run: `library(reticulate); use_condaenv("myRSamGeo", required = TRUE)`
- [ ] Verify: `py_config()` shows correct path
- [ ] Load other packages
- [ ] Run your analysis

## Alternative: Use .Rprofile

To automate this, add to your project `.Rprofile`:

```r
if (interactive()) {
  Sys.setenv(RETICULATE_PYTHON = "")
  tryCatch({
    library(reticulate)
    use_condaenv("myRSamGeo", required = TRUE)
    message("✓ Using myRSamGeo conda environment")
  }, error = function(e) {
    message("⚠ Could not set myRSamGeo environment: ", e$message)
  })
}
```

Then restart R, and it will automatically set the environment on startup.

## Verifying Your Setup

Run this to check everything:

```r
library(reticulate)
use_condaenv("myRSamGeo", required = TRUE)

# Check Python
py_config()

# Check packages
py_list_packages() |> subset(package %in% c("samgeo", "torch", "segment-geospatial"))

# Load rsamgeo
library(rsamgeo)

# Check versions
sg_version()
sg_torch_cuda_is_available()
```

If all commands work without errors, you're ready to go!
