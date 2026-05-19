#' Open .mzML File
#'
#' Open and parse a .mzML file containing Selective Reaction Monitoring (SRM) Mass Spectrometry (MS) data using `xml2`
#'
#' @param mzml_file the absolute file path of a valid `.mzML` file
#' @return a list of two elements containing `peaks` and `header`
#'
#' @export
#' @importFrom magrittr %>%

openFile <- function(mzml_file)
{
  xml_tmp <- xml2::read_xml(mzml_file)

  pwiz_version <-
    xml_tmp %>% xml2::xml_find_all(., "//d1:software") %>% xml2::xml_attrs() %>%
    dplyr::bind_rows() %>% dplyr::filter(id == 'pwiz') %>%
    dplyr::select(version) %>% dplyr::pull() %>%
    stringr::str_split(., '\\.')

  pwiz_version_major <- paste0(pwiz_version[[1]][1], '.', pwiz_version[[1]][2]) %>% as.numeric(.)
  pwiz_version_minor <- pwiz_version[[1]][[3]] %>% as.numeric()

  if(pwiz_version_major >= 3 &
     pwiz_version_minor <= 20000) {
    message(
      crayon::red(
        cli::symbol$warning,
        'Use mzR for files converted with pwiz version <= 3.0.2000'
      )
    )
    return(invisible(NULL))
  }

  id_refs_raw <- idRefs(xml_tmp)

  id_refs <- stringr::str_replace_all(id_refs_raw, ' ', '.')

  id_refs <- stringr::str_replace_all(id_refs , ',', '.')

  chrom_blocks <-
    xml_tmp %>% xml2::xml_find_all(., "//d1:chromatogram") %>%
    purrr::map(., xml2::xml_children)

  parse_ref <- tibble::tibble(idRef = id_refs, mode = NA)
  parse_ref$mode[parse_ref$idRef == 'TIC'] <- 'TIC'
  parse_ref$mode[parse_ref$idRef != 'TIC'] <- 'SRM'

  parsed_chrom_blocks <-
    purrr::map2(chrom_blocks, parse_ref$mode, ~ {
      parseChromNode(.x, mode = .y)
    })

  precisionCheck <- function(accession)
  {
    if ('MS:1000523' %in% accession) {
      p <- 64
    }
    if ('MS:1000521' %in% accession) {
      p <- 32
    }

    return(p)
  }

  peaks <- list()
  for (i in seq_along(parsed_chrom_blocks)) {
    rt_tmp <- parsed_chrom_blocks[[i]]$time
    int_tmp <- parsed_chrom_blocks[[i]]$intensity

    rt_p <- precisionCheck(rt_tmp$attributes$accession)
    int_p <- precisionCheck(int_tmp$attributes$accession)


    peaks[[i]] <-
      data.frame(
        time = decodePeaks(rt_tmp$raw, compression = 'none', size = rt_p / 8),
        int = decodePeaks(int_tmp$raw, compression = 'none', size = int_p /
                            8)
      )

    names(peaks[[i]])[2] <- id_refs[[i]]


  }


  Precursor <-
    xml_tmp %>% xml2::xml_find_all(., "//d1:precursor") %>%
    purrr::map(., xml2::xml_children) %>%
    purrr::map(., xml2::xml_children) %>%
    purrr::map(., xml2::xml_attrs) %>%
    purrr::map(., dplyr::bind_rows) %>%
    purrr::map(., ~ {
      dplyr::filter(., accession == 'MS:1000827' |
                      accession == 'MS:1000045') %>%
        dplyr::select(., name, value)
    })




  Product <-
    xml_tmp %>% xml2::xml_find_all(., "//d1:product") %>%
    purrr::map(., xml2::xml_children) %>%
    purrr::map(., xml2::xml_children) %>%
    purrr::map(., xml2::xml_attrs) %>%
    purrr::map(., dplyr::bind_rows) %>%
    purrr::map(., ~ {
      dplyr::select(., name, value)
    })


  srm_id <-
    tibble::tibble(id_refs, id = seq(
      from = 1,
      to = length(id_refs),
      by = 1
    )) %>% dplyr::filter(id_refs != 'TIC')

  for (i in seq_along(srm_id$id)) {
    Precursor[[i]] <-
      Precursor[[i]] %>% dplyr::mutate(chromatogramIndex = srm_id$id[i]) %>%
      tidyr::pivot_wider(names_from = name, values_from = value)

    Product[[i]] <-
      Product[[i]] %>% dplyr::mutate(chromatogramIndex = srm_id$id[i]) %>%
      tidyr::pivot_wider(names_from = name, values_from = value)
  }


  PrecursorHeader <- Precursor %>% dplyr::bind_rows() %>%
    dplyr::rename(
      precursorIsolationWindowTargetMZ = 'isolation window target m/z',
      precursorCollisionEnergy = 'collision energy'
    ) %>%
    dplyr::mutate_if(is.character, as.numeric)

  PrecursorHeader$precursorIsolationWindowTargetMZ <-
    round(PrecursorHeader$precursorIsolationWindowTargetMZ,
          digits = 3)


  ProductHeader <- Product %>% dplyr::bind_rows() %>%
    dplyr::rename(
      productIsolationWindowTargetMZ = 'isolation window target m/z',
      productIsolationWindowLowerOffset = 'isolation window lower offset',
      productIsolationWindowUpperOffset = 'isolation window upper offset'
    ) %>%
    dplyr::mutate_if(is.character, as.numeric)

  ProductHeader$productIsolationWindowTargetMZ <-
    round(ProductHeader$productIsolationWindowTargetMZ,
          digits = 3)


  header_tibble <- tibble::tibble(
    chromatogramId = id_refs_raw,
    chromatogramIndex = seq(
      from = 1,
      to = length(id_refs),
      by = 1
    ),
    polarity = purrr::map_dbl(parsed_chrom_blocks, ~ {
      .$polarity
    }),
    precursorIsolationWindowLowerOffset = NA,
    precursorIsolationWindowUpperOffset = NA
  )


  file_header <-
    header_tibble %>% dplyr::full_join(., PrecursorHeader, by = 'chromatogramIndex') %>%
    dplyr::full_join(., ProductHeader, by = 'chromatogramIndex') %>%
    dplyr::select(
      chromatogramId,
      chromatogramIndex,
      polarity,
      precursorIsolationWindowTargetMZ,
      precursorIsolationWindowLowerOffset,
      precursorIsolationWindowUpperOffset,
      precursorCollisionEnergy,
      productIsolationWindowTargetMZ,
      productIsolationWindowLowerOffset,
      productIsolationWindowUpperOffset
    )

  file_header$chromatogramIndex <- as.integer(file_header$chromatogramIndex)
  file_header$polarity <- as.integer(file_header$polarity)

  file_header$precursorIsolationWindowLowerOffset <- as.numeric(file_header$precursorIsolationWindowLowerOffset)
  file_header$precursorIsolationWindowUpperOffset <- as.numeric(file_header$precursorIsolationWindowUpperOffset)
  file_header$precursorCollisionEnergy[file_header$precursorCollisionEnergy == 0] <- NA


  return(list(peaks = peaks, header = data.frame(file_header)))



}
