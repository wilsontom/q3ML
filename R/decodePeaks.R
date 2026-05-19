#' Decode peaks
#'
#' Decode a `binaryDataArray` into a vector of either time or intensity
#'
#' @param x a `base64` encoded vector
#' @param compression compression type (default = "none")
#' @param size a numeric value for the number of bytes per element in the byte stream
#' @return a numeric vector

decodePeaks <- function(x, compression = "none", size)
{
  x <- base64enc::base64decode(x)
  raw_x <- as.raw(x)

  raw_x2 <- memDecompress(from = raw_x, type = compression)

  bins_x <-
    readBin(
      raw_x2,
      what = "double",
      n = length(raw_x2) / size,
      size = size,
      endian = .Platform$endian
    )

  return(bins_x)
}
