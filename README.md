# q3ML

[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![R-CMD-check.yaml](https://github.com/wilsontom/q3ML/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/wilsontom/q3ML/actions/workflows/R-CMD-check.yaml) [![test-coverage.yaml](https://github.com/wilsontom/q3ML/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/wilsontom/q3ML/actions/workflows/test-coverage.yaml)
![Test coverage](https://raw.githubusercontent.com/wilsontom/q3ML/coverage/badges/coverage.svg)
![License](https://img.shields.io/badge/license-GNU%20GPL%20v3.0-blue.svg "GNU GPL v3.0")

`q3ML` opens and parses selective reaction monitoring (SRM) `.mzML` files from Thermo triple quadrupole instruments using direct XML and binary decoding in R. It is aimed at cases where an `.mzML` file is structurally valid but `mzR` cannot decode the chromatogram binary arrays produced by newer ProteoWizard conversions.

## Installation

Install the development version from GitHub:

```r
remotes::install_github("wilsontom/q3ML")
```

## When To Use q3ML

`openFile()` inspects the embedded ProteoWizard version in the `.mzML` file.

- For files converted with ProteoWizard `<= 3.0.20000`, `openFile()` prints a message and returns `NULL`. Those files should be opened with `mzR`.
- For files converted with ProteoWizard `> 3.0.20000`, `openFile()` parses the chromatograms directly and returns the extracted data.

This means `q3ML` is best used as a targeted fallback for newer SRM `.mzML` files rather than as a full replacement for `mzR`.

## What `openFile()` Returns

`openFile()` returns a list with two elements:

- `peaks`: a list of chromatogram peak tables. Each table contains `time` plus one intensity column named from the chromatogram id.
- `header`: a `data.frame` describing each chromatogram, including polarity and precursor/product isolation window metadata.

## Example

```r
library(q3ML)
library(mzR)

mzml_files <- list.files(
  system.file("extdata", package = "q3ML"),
  full.names = TRUE
)

# Older ProteoWizard output: use mzR
openFile(mzml_files[1])
#> ! Use mzR for files converted with pwiz version <= 3.0.20000
#> NULL

legacy <- mzR::openMSfile(mzml_files[1])
legacy_header <- mzR::chromatogramHeader(legacy)
legacy_peaks <- mzR::chromatograms(legacy)
mzR::close(legacy)

# Newer ProteoWizard output: parse with q3ML
parsed <- openFile(mzml_files[2])

str(parsed, max.level = 1)
#> List of 2
#>  $ peaks :List of 107
#>  $ header:'data.frame': 107 obs. of 10 variables

# The bundled fixtures represent the same chromatograms exported with
# different ProteoWizard versions, so the parsed outputs match.
identical(parsed$header, legacy_header)
#> [1] TRUE

identical(parsed$peaks, legacy_peaks)
#> [1] TRUE
```

## Documentation

Package documentation is available at:

<https://wilsontom.github.io/q3ML/>
