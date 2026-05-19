# q3ML

[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable) [![R-CMD-check](https://github.com/wilsontom/q3ML/workflows/R-CMD-check/badge.svg)](https://github.com/wilsontom/q3ML/actions) [![codecov](https://codecov.io/gh/wilsontom/q3ML/branch/main/graph/badge.svg?token=D0wfktJfzp)](https://codecov.io/gh/wilsontom/q3ML) ![License](https://img.shields.io/badge/license-GNU%20GPL%20v3.0-blue.svg "GNU GPL v3.0")

> __Pwiz Free Parsing for Selective Reaction Monitoring (SRM) Mass Spectrometry (MS) .mzML Files__

## Installation

`q3ML` can de installed directly from GitHub using the `remotes` packages

```r
remotes::install_github('wilsontom/q3ML')
```
## Learn More

The package documentation can be browsed online at [https://wilsontom/github.io/q3ML](https://wilsontom/github.io/q3ML).


## Quick Start

For mzML files that have been converted using msconvert pwiz Version 3.0.2000 or lower, then `mzR` should be used to open the files. 

```R
library(q3ML)

mzml_files <- list.files(system.file('extdata', package = 'q3ML'),
                         full.names = TRUE)


Pwiz_301 <- openFile(mzml_files[1])                         
! Use mzR for files converted with pwiz version <= 3.0.2000

Pwiz_301 <- mzR::openMSfile(mzml_files[1])

> Pwiz_V3_01
Mass Spectrometry file handle.
Filename:  QC01_pwiz3_0_1.mzML 
Number of scans:  0 

```

For .mzML files which have been created using msconvert pwiz Version > 3.0.2 then `q3ML` can be used to parse the file, if `mzR` throws an error.

```R
Pwiz_V3_02 <- mzR::openMSfile(mzml_files[2])

Error: Can not open file /home/R/x86_64-pc-linux-gnu-library/4.1/q3ML/extdata/QC01_pwiz3_0_2.mzML! 
Original error was: Error in pwizModule$open(filename): [IO::HandlerBinaryDataArray] Unknown binary data type.

Pwiz_V3_02 <- openFile(mzml_files[2])



identical(Pwiz_V3_02$header,mzR::chromatogramHeader(Pwiz_V3_01))
[1] TRUE

identical(Pwiz_V3_02$peaks,mzR::chromatograms(Pwiz_V3_01))
[1] TRUE
```











