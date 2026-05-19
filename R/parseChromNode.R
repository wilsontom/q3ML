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
  chrom_node <- if (inherits(x, "xml_node") &&
                    identical(xml2::xml_name(x), "chromatogram")) {
    x
  } else if (length(x) > 0 && inherits(x[[1]], "xml_node")) {
    xml2::xml_parent(x[[1]])
  } else {
    stop("`x` must describe a chromatogram node.", call. = FALSE)
  }

  binaryDataArray <- xml2::xml_find_all(
    chrom_node,
    "./d1:binaryDataArrayList/d1:binaryDataArray"
  )

  array_by_accession <- function(accession)
  {
    matches <- purrr::keep(binaryDataArray, ~ {
      accessions <- xml2::xml_find_all(.x, "./d1:cvParam") %>%
        xml2::xml_attrs() %>%
        dplyr::bind_rows() %>%
        dplyr::pull(accession)

      accession %in% accessions
    })

    if (length(matches) != 1) {
      stop("Unable to find a unique binary data array in the chromatogram.",
           call. = FALSE)
    }

    matches[[1]]
  }

  parse_array <- function(binary_array)
  {
    array_attr <-
      xml2::xml_find_all(binary_array, "./d1:cvParam") %>%
      xml2::xml_attrs() %>%
      dplyr::bind_rows() %>%
      dplyr::select(dplyr::any_of(c("cvRef", "accession", "name"))) %>%
      dplyr::filter(!is.na(cvRef))

    array_raw <- xml2::xml_text(xml2::xml_find_first(binary_array, "./d1:binary"))

    list(attributes = array_attr, raw = array_raw)
  }

  if (mode == 'TIC') {
    polarity <- -1
  }

  if (mode == 'SRM') {
    plong <- xml2::xml_find_first(
      chrom_node,
      "./d1:cvParam[@name='positive scan' or @name='negative scan']"
    ) %>% xml2::xml_attr("name")

    if (!is.na(plong) && plong == 'positive scan') {
      polarity <- 1
    }

    if (!is.na(plong) && plong == 'negative scan') {
      polarity <- 0
    }

    if (is.na(plong)) {
      polarity <- NA_integer_
    }

  }

  time_array <- parse_array(array_by_accession("MS:1000595"))
  intensity_array <- parse_array(array_by_accession("MS:1000515"))

  chrom_list <- list(
    time = time_array,
    intensity = intensity_array,
    polarity = polarity
  )

  return(chrom_list)


}
