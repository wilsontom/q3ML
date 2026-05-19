#' Parse the XML nodeset of a SRM chromatogram
#'
#' @param x a `xml2` nodeset for a `Chromatogram` block
#' @param mode a character of either `SRM` or `TIC`
#' @return a list of two elements
#'  * **time**
#'    * `attributes`
#'    * `raw`
#'  * **intensity**
#'    * `attributes`
#'    * `raw`
#' @export

parseChromNode <- function(x, mode)
{
  if (mode == 'TIC') {
    binaryDataArray <- xml2::xml_children(x[[2]])
    polarity <- -1
  }

  if (mode == 'SRM') {
    binaryDataArray <- xml2::xml_children(x[[5]])

    plong <- xml2::xml_attrs(x[[2]])[['name']]

    if (plong == 'positive scan') {
      polarity <- 1
    }

    if (plong == 'negative scan') {
      polarity <- 0
    }

  }


  time_array <- binaryDataArray[[1]] %>% xml2::xml_children()
  intensity_array <- binaryDataArray[[2]] %>% xml2::xml_children()


  time_attr <-
    xml2::xml_attrs(time_array) %>% dplyr::bind_rows() %>%
    dplyr::select(cvRef, accession, name) %>% dplyr::filter(!is.na(cvRef))

  time_raw <- xml2::xml_text(time_array[[4]])

  intensity_attr <-
    xml2::xml_attrs(intensity_array) %>% dplyr::bind_rows() %>%
    dplyr::select(cvRef, accession, name) %>% dplyr::filter(!is.na(cvRef))

  intensity_raw <- xml2::xml_text(intensity_array[[4]])


  chrom_list <- list(
    time = list(attributes = time_attr,
                raw = time_raw),
    intensity = list(attributes = intensity_attr,
                     raw = intensity_raw),
    polarity = polarity
  )

  return(chrom_list)


}
