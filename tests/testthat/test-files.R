fixture_file <- function(path)
{
  local_path <- testthat::test_path("..", "..", "inst", "extdata", path)

  if (file.exists(local_path)) {
    return(local_path)
  }

  system.file("extdata", path, package = "q3ML")
}

write_fixture_variant <- function(path, edit_xml)
{
  xml <- xml2::read_xml(path)
  edit_xml(xml)

  variant <- tempfile(fileext = ".mzML")
  xml2::write_xml(xml, variant)
  variant
}

test_that("file versions", {
  old_fixture <- fixture_file("QC01_pwiz3_0_1.mzML")
  new_fixture <- fixture_file("QC01_pwiz3_0_2.mzML")

  expect_true(file.exists(old_fixture))
  expect_true(file.exists(new_fixture))

  old_mzr <- mzR::openMSfile(old_fixture)
  on.exit(mzR::close(old_mzr), add = TRUE)

  expect_true(inherits(old_mzr, "mzRpwiz"))
  expect_null(openFile(old_fixture))

  q3ml_result <- openFile(new_fixture)
  expect_true(is.list(q3ml_result))

  mzr_result <- mzR::openMSfile(new_fixture)
  on.exit(mzR::close(mzr_result), add = TRUE)

  expect_identical(mzR::chromatograms(mzr_result), q3ml_result$peaks)
  expect_identical(mzR::chromatogramHeader(mzr_result), q3ml_result$header)
})

test_that("ProteoWizard version checks are semantic", {
  future_fixture <- write_fixture_variant(
    fixture_file("QC01_pwiz3_0_2.mzML"),
    function(xml) {
      pwiz <- xml2::xml_find_first(xml, "//d1:software[@id='pwiz']")
      xml2::xml_set_attr(pwiz, "version", "4.0.00001")
    }
  )
  on.exit(unlink(future_fixture), add = TRUE)

  expect_true(is.list(openFile(future_fixture)))
})

test_that("chromatogram parsing is resilient to cvParam ordering", {
  baseline_fixture <- fixture_file("QC01_pwiz3_0_2.mzML")
  baseline <- openFile(baseline_fixture)

  reordered_fixture <- write_fixture_variant(
    baseline_fixture,
    function(xml) {
      chromatogram <- xml2::xml_find_all(xml, "//d1:chromatogram")[[2]]
      positive_scan <- xml2::xml_find_first(
        chromatogram,
        "./d1:cvParam[@name='positive scan']"
      )

      xml2::xml_add_sibling(
        positive_scan,
        "before",
        .value = xml2::read_xml(
          "<cvParam cvRef='MS' accession='MS:1000235' name='total ion current chromatogram' value=''/>"
        )
      )
    }
  )
  on.exit(unlink(reordered_fixture), add = TRUE)

  reordered <- openFile(reordered_fixture)

  expect_identical(reordered$peaks, baseline$peaks)
  expect_identical(reordered$header, baseline$header)
})

test_that("openFile errors when the ProteoWizard version cannot be determined", {
  no_pwiz_fixture <- write_fixture_variant(
    fixture_file("QC01_pwiz3_0_2.mzML"),
    function(xml) {
      pwiz <- xml2::xml_find_first(xml, "//d1:software[@id='pwiz']")
      xml2::xml_set_attr(pwiz, "id", "not-pwiz")
    }
  )
  on.exit(unlink(no_pwiz_fixture), add = TRUE)

  expect_error(
    openFile(no_pwiz_fixture),
    "Unable to determine the ProteoWizard version"
  )
})

test_that("idRefs validates inputs and extracts idRef values", {
  fixture <- fixture_file("QC01_pwiz3_0_2.mzML")
  xml <- xml2::read_xml(fixture)

  expect_error(
    q3ML:::idRefs("not-xml"),
    "xmlDoc must be an xml_documment"
  )

  refs <- q3ML:::idRefs(xml)

  expect_length(refs, length(xml2::xml_find_all(xml, "//d1:offset")))
  expect_identical(refs[[1]], "TIC")
})

test_that("parseChromNode supports nodesets and polarity variants", {
  fixture <- fixture_file("QC01_pwiz3_0_2.mzML")
  xml <- xml2::read_xml(fixture)
  chromatograms <- xml2::xml_find_all(xml, "//d1:chromatogram")

  positive_node <- chromatograms[[2]]
  positive_from_node <- parseChromNode(positive_node, "SRM")
  positive_from_nodeset <- parseChromNode(xml2::xml_children(positive_node), "SRM")

  expect_identical(positive_from_nodeset, positive_from_node)
  expect_identical(positive_from_node$polarity, 1)

  negative_fixture <- write_fixture_variant(
    fixture,
    function(xml) {
      positive_scan <- xml2::xml_find_first(
        xml2::xml_find_all(xml, "//d1:chromatogram")[[2]],
        "./d1:cvParam[@name='positive scan']"
      )
      xml2::xml_set_attr(positive_scan, "name", "negative scan")
    }
  )
  on.exit(unlink(negative_fixture), add = TRUE)

  negative_xml <- xml2::read_xml(negative_fixture)
  negative_chrom <- xml2::xml_find_all(negative_xml, "//d1:chromatogram")[[2]]

  expect_identical(parseChromNode(negative_chrom, "SRM")$polarity, 0)

  missing_polarity_fixture <- write_fixture_variant(
    fixture,
    function(xml) {
      positive_scan <- xml2::xml_find_first(
        xml2::xml_find_all(xml, "//d1:chromatogram")[[2]],
        "./d1:cvParam[@name='positive scan']"
      )
      xml2::xml_remove(positive_scan)
    }
  )
  on.exit(unlink(missing_polarity_fixture), add = TRUE)

  missing_polarity_xml <- xml2::read_xml(missing_polarity_fixture)
  missing_polarity_chrom <- xml2::xml_find_all(
    missing_polarity_xml,
    "//d1:chromatogram"
  )[[2]]

  expect_true(is.na(parseChromNode(missing_polarity_chrom, "SRM")$polarity))
})

test_that("parseChromNode validates chromatogram structure", {
  fixture <- fixture_file("QC01_pwiz3_0_2.mzML")
  xml <- xml2::read_xml(fixture)

  expect_error(
    parseChromNode("not-a-node", "SRM"),
    "`x` must describe a chromatogram node."
  )

  duplicate_time_fixture <- write_fixture_variant(
    fixture,
    function(xml) {
      chromatogram <- xml2::xml_find_all(xml, "//d1:chromatogram")[[2]]
      binary_arrays <- xml2::xml_find_all(
        chromatogram,
        "./d1:binaryDataArrayList/d1:binaryDataArray"
      )
      duplicated <- xml2::read_xml(as.character(binary_arrays[[1]]))
      xml2::xml_add_sibling(binary_arrays[[1]], "after", .value = duplicated)
    }
  )
  on.exit(unlink(duplicate_time_fixture), add = TRUE)

  duplicate_time_xml <- xml2::read_xml(duplicate_time_fixture)
  duplicate_time_chrom <- xml2::xml_find_all(
    duplicate_time_xml,
    "//d1:chromatogram"
  )[[2]]

  expect_error(
    parseChromNode(duplicate_time_chrom, "SRM"),
    "Unable to find a unique binary data array"
  )
})
