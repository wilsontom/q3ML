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
