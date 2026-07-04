# generateMismatchData() and saveReport(): the remaining dataCompareR
# compatibility surface.

test_that("generateMismatchData returns mismatching rows of both frames", {
  cmp <- rCompare(rc_a, rc_b, keys = "id")
  out <- generateMismatchData(cmp, rc_a, rc_b)
  expect_named(out, c("rc_a_mm", "rc_b_mm"))
  expect_named(out$rc_a_mm, c("ID", "VAL", "CHR", "ONLY_A"))
  expect_named(out$rc_b_mm, c("ID", "VAL", "CHR", "ONLY_B"))
  expect_identical(out$rc_a_mm$ID, 2L)
  expect_identical(out$rc_a_mm$VAL, 2)
  expect_identical(out$rc_b_mm$VAL, 2.5)
})

test_that("generateMismatchData works on keyless comparisons by row position", {
  a <- data.frame(v = 1:3, w = c("x", "y", "z"))
  b <- data.frame(v = c(1L, 9L, 3L), w = c("x", "y", "q"))
  cmp <- rCompare(a, b)
  out <- generateMismatchData(cmp, a, b)
  expect_named(out, c("a_mm", "b_mm"))
  # keyless frames keep their original names, as in dataCompareR
  expect_named(out$a_mm, c("v", "w"))
  expect_identical(out$a_mm$v, 2:3)
  expect_identical(out$b_mm$v, c(9L, 3L))
})

test_that("generateMismatchData accepts the frames in either order", {
  cmp <- rCompare(rc_a, rc_b, keys = "id")
  out <- generateMismatchData(cmp, rc_b, rc_a)
  expect_named(out, c("rc_a_mm", "rc_b_mm"))
  expect_identical(out$rc_b_mm$VAL, 2.5)
})

test_that("generateMismatchData validates the frame names against the comparison", {
  cmp <- rCompare(rc_a, rc_b, keys = "id")
  zz <- rc_a
  expect_error(generateMismatchData(cmp, zz, rc_b), "zz")
  expect_error(generateMismatchData(list(), rc_a, rc_b))
})

test_that("generateMismatchData returns empty frames when nothing mismatches", {
  a <- data.frame(id = 1:2, v = c(1, 2))
  cmp <- rCompare(a, a, keys = "id")
  out <- generateMismatchData(cmp, a, a)
  expect_named(out, c("a_mm", "a_mm"))
  expect_identical(nrow(out[[1]]), 0L)
  expect_identical(nrow(out[[2]]), 0L)
})

test_that("saveReport writes an Rmd capture of the summary report", {
  dir <- withr::local_tempdir()
  cmp <- rCompare(rc_a, rc_b, keys = "id")
  res <- saveReport(
    cmp,
    reportName = "myreport",
    reportLocation = dir,
    HTMLReport = FALSE,
    showInViewer = FALSE
  )
  expect_null(res)
  rmd <- file.path(dir, "myreport.Rmd")
  expect_true(file.exists(rmd))
  lines <- readLines(rmd)
  expect_true(any(grepl("^Data Comparison$", lines)))
  expect_true(any(grepl("^Unequal column details$", lines)))
  expect_false(file.exists(file.path(dir, "myreport.html")))
})

test_that("saveReport renders HTML when requested", {
  skip_if_not(rmarkdown::pandoc_available())
  dir <- withr::local_tempdir()
  cmp <- rCompare(rc_a, rc_b, keys = "id")
  saveReport(
    cmp,
    reportName = "myreport",
    reportLocation = dir,
    showInViewer = FALSE
  )
  expect_true(file.exists(file.path(dir, "myreport.html")))
})

test_that("saveReport printAll includes every mismatch row", {
  dir <- withr::local_tempdir()
  a <- data.frame(id = 1:10, v = 1:10)
  b <- data.frame(id = 1:10, v = rep(0L, 10))
  cmp <- rCompare(a, b, keys = "id")
  saveReport(
    cmp,
    reportName = "capped",
    reportLocation = dir,
    HTMLReport = FALSE,
    showInViewer = FALSE
  )
  saveReport(
    cmp,
    reportName = "full",
    reportLocation = dir,
    HTMLReport = FALSE,
    showInViewer = FALSE,
    printAll = TRUE
  )
  capped <- readLines(file.path(dir, "capped.Rmd"))
  full <- readLines(file.path(dir, "full.Rmd"))
  expect_gt(length(full), length(capped))
  expect_true(any(grepl("\\| *10\\| *10\\| *0\\|", full)))
})

test_that("saveReport validates its arguments", {
  cmp <- rCompare(rc_a, rc_b, keys = "id")
  expect_error(saveReport(cmp, reportName = 1, reportLocation = tempdir()))
  expect_error(saveReport(
    cmp,
    reportName = "x",
    reportLocation = "/nonexistent/dir"
  ))
  expect_error(saveReport(list(), reportName = "x", reportLocation = tempdir()))
})

test_that("render_diff on a compat object produces the datadiffr HTML report", {
  skip_if_not_installed("flexdashboard")
  skip_if_not(rmarkdown::pandoc_available())
  dir <- withr::local_tempdir()
  out_file <- file.path(dir, "diff.html")
  cmp <- rCompare(rc_a, rc_b, keys = "id")
  res <- render_diff(cmp, output_file = out_file)
  expect_true(file.exists(out_file))
  expect_identical(res, out_file)
})

test_that("render_diff on an all-equal compat object reports nothing to render", {
  a <- data.frame(id = 1:2, v = c(1, 2))
  cmp <- rCompare(a, a, keys = "id")
  expect_message(
    expect_null(render_diff(cmp)),
    "No differences"
  )
})
