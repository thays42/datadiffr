# summary()/print() methods for the dataCompareR compatibility object.
# Field list and shapes pinned against dataCompareR 0.1.4.

summary_names <- c(
  "datanameA",
  "datanameB",
  "nrowA",
  "nrowB",
  "rounding",
  "roundDigits",
  "version",
  "runtime",
  "rversion",
  "datasetSummary",
  "ncolCommon",
  "ncolInAOnly",
  "ncolInBOnly",
  "colsInAOnly",
  "colsInBOnly",
  "colsInBoth",
  "ncolID",
  "matchKey",
  "typeMismatch",
  "typeMismatchN",
  "nrowCommon",
  "nrowInAOnly",
  "nrowInBOnly",
  "rowsInAOnly",
  "rowsInBOnly",
  "ncolsAllEqual",
  "ncolsSomeUnequal",
  "colsWithUnequalValues",
  "nrowNAmismatch",
  "ColsMatching",
  "maxDifference",
  "colMismDetls",
  "mismatchCount"
)

test_that("summary returns the dataCompareR field set in order", {
  s <- summary(rCompare(rc_a, rc_b, keys = "id"))
  expect_s3_class(s, "summary.datadiff_compare")
  expect_s3_class(s, "summary.dataCompareRobject")
  expect_named(s, summary_names)
})

test_that("summary reports names, dimensions, and run metadata", {
  s <- summary(rCompare(rc_a, rc_b, keys = "id"))
  expect_identical(s$datanameA, "rc_a")
  expect_identical(s$datanameB, "rc_b")
  expect_identical(s$nrowA, 4L)
  expect_identical(s$nrowB, 4L)
  expect_identical(s$rounding, FALSE)
  expect_identical(s$roundDigits, 0)
  expect_identical(s$version, utils::packageVersion("datadiffr"))
  expect_s3_class(s$runtime, "POSIXct")
  expect_identical(s$rversion, R.version.string)
  expect_identical(
    s$datasetSummary,
    data.frame(
      "Dataset Name" = c("rc_a", "rc_b"),
      "Number of Rows" = c("4", "4"),
      "Number of Columns" = c("4", "4"),
      check.names = FALSE
    )
  )
  expect_identical(s$maxDifference, NA)
  expect_identical(s$mismatchCount, 5)
})

test_that("summary reports column matching", {
  s <- summary(rCompare(rc_a, rc_b, keys = "id"))
  expect_identical(s$ncolCommon, 3L)
  expect_identical(s$ncolInAOnly, 1L)
  expect_identical(s$ncolInBOnly, 1L)
  expect_identical(s$colsInAOnly, "only_a")
  expect_identical(s$colsInBOnly, "only_b")
  expect_identical(s$colsInBoth, c("CHR", "ID", "VAL"))
  expect_identical(s$ncolID, 1L)
  expect_identical(s$matchKey, "ID")
  expect_named(
    s$typeMismatch,
    c("Column Name", "Column Type (in rc_a)", "Column Type (in rc_b)")
  )
  expect_identical(nrow(s$typeMismatch), 0L)
  expect_identical(s$typeMismatchN, 0L)
})

test_that("summary reports row matching", {
  s <- summary(rCompare(rc_a, rc_b, keys = "id"))
  expect_identical(s$nrowCommon, 3L)
  expect_identical(s$nrowInAOnly, 1)
  expect_identical(s$nrowInBOnly, 1)
  expect_equal(s$rowsInAOnly, data.frame(ID = 4L))
  expect_equal(s$rowsInBOnly, data.frame(ID = 5L))
})

test_that("summary reports value comparison results", {
  s <- summary(rCompare(rc_a, rc_b, keys = "id"))
  expect_identical(s$ncolsAllEqual, 0L)
  expect_identical(s$ncolsSomeUnequal, 2L)
  expect_named(
    s$colsWithUnequalValues,
    c(
      "Column",
      "Type (in rc_a)",
      "Type (in rc_b)",
      "# differences",
      "Max difference",
      "# NAs"
    )
  )
  expect_identical(s$colsWithUnequalValues$Column, c("CHR", "VAL"))
  expect_identical(s$colsWithUnequalValues$`# differences`, c(1L, 1L))
  expect_identical(s$colsWithUnequalValues$`Max difference`, c(NA, "0.5"))
  expect_identical(s$colsWithUnequalValues$`# NAs`, c(0L, 0L))
  expect_identical(s$nrowNAmismatch, 0L)
  expect_identical(as.character(s$ColsMatching), character())
})

test_that("summary details carry per-column mismatch tables with dynamic names", {
  s <- summary(rCompare(rc_a, rc_b, keys = "id"))
  expect_named(s$colMismDetls, c("CHR", "VAL"))
  expect_named(
    s$colMismDetls$VAL,
    c(
      "ID",
      "VAL (rc_a)",
      "VAL (rc_b)",
      "Type (rc_a)",
      "Type (rc_b)",
      "Difference"
    )
  )
  expect_identical(s$colMismDetls$VAL$Difference, -0.5)
})

test_that("summary detail tables sort by decreasing absolute difference and cap at mismatchCount", {
  a <- data.frame(id = 1:4, v = c(1, 2, 3, 4))
  b <- data.frame(id = 1:4, v = c(1, 4, 10, 4))
  s <- summary(rCompare(a, b, keys = "id"))
  expect_identical(s$colMismDetls$V$Difference, c(-7, -2))
  s2 <- summary(rCompare(a, b, keys = "id"), mismatchCount = 1)
  expect_identical(s2$colMismDetls$V$ID, 3L)
  expect_identical(s2$mismatchCount, 1)
  # colsWithUnequalValues is never capped
  expect_identical(s2$colsWithUnequalValues$`# differences`, 2L)
})

test_that("summary of a keyless comparison reports dropped indices", {
  a <- data.frame(v = 1:5, w = letters[1:5])
  b <- data.frame(v = c(1L, 2L, 9L), w = c("a", "x", "c"))
  s <- summary(rCompare(a, b))
  expect_identical(s$ncolID, 0L)
  expect_identical(s$matchKey, NA_character_)
  expect_identical(s$nrowCommon, 3L)
  expect_identical(s$nrowInAOnly, 2)
  expect_equal(s$rowsInAOnly, data.frame(indices_removed = 4:5))
  expect_identical(nrow(s$rowsInBOnly), 0L)
  # keyless detail tables have no key columns
  expect_named(
    s$colMismDetls$V,
    c("V (a)", "V (b)", "Type (a)", "Type (b)", "Difference")
  )
})

test_that("summary reports type mismatches and NA differences", {
  a <- data.frame(id = 1:4, t = c(1L, 2L, 3L, 4L), n = c(NA, 2, 3, 4))
  b <- data.frame(id = 1:4, t = c(1.0, 2.0, 3.0, 4.5), n = c(NA, 2, 9, NA))
  s <- summary(rCompare(a, b, keys = "id"))
  expect_identical(s$typeMismatchN, 1L)
  expect_identical(s$typeMismatch$`Column Name`, "T")
  expect_identical(s$typeMismatch$`Column Type (in a)`, "integer")
  expect_identical(s$typeMismatch$`Column Type (in b)`, "double")
  cwu <- s$colsWithUnequalValues
  expect_identical(cwu$Column, c("N", "T"))
  expect_identical(cwu$`Max difference`, c("6", NA))
  expect_identical(cwu$`# NAs`, c(1L, 0L))
  expect_identical(s$nrowNAmismatch, 1L)
})

test_that("print reports an all-equal comparison", {
  a <- data.frame(x = 1:2)
  expect_output(print(rCompare(a, a)), "All columns were compared")
  expect_output(print(rCompare(a, a)), "all rows were compared")
  expect_output(print(rCompare(a, a)), "All compared variables match")
  expect_output(print(rCompare(a, a)), "Number of rows compared: 2")
  expect_output(print(rCompare(a, a)), "Number of columns compared: 1")
})

test_that("print reports dropped columns and rows", {
  out <- capture.output(print(rCompare(rc_a, rc_b, keys = "id")))
  expect_match(
    out[1],
    "2 column\\(s\\) were dropped, 2 row\\(s\\) were dropped from comparison"
  )
})

test_that("print shows mismatched variables with head/tail observations", {
  out <- capture.output(print(rCompare(rc_a, rc_b, keys = "id")))
  expect_match(out, "There are +2 mismatched variables:", all = FALSE)
  expect_match(
    out,
    "First and last 5 observations for the +2 mismatched variables",
    all = FALSE
  )
  expect_match(out, "valueA", all = FALSE)
  expect_match(out, "2\\.5", all = FALSE)
})

test_that("print limits variables and observations via nVars/nObs", {
  out <- capture.output(
    print(rCompare(rc_a, rc_b, keys = "id"), nVars = 1, nObs = 1)
  )
  expect_match(
    out,
    "First and last 1 observations for first and last 1 mismatched variables",
    all = FALSE
  )
})

test_that("print verbose shows every mismatch row", {
  a <- data.frame(id = 1:6, v = 1:6)
  b <- data.frame(id = 1:6, v = rep(0L, 6))
  out <- capture.output(print(rCompare(a, b, keys = "id"), verbose = TRUE))
  expect_length(grep("^\\d", trimws(out)), 6)
})

test_that("print returns its argument invisibly", {
  a <- data.frame(x = 1)
  cmp <- rCompare(a, a)
  out <- withVisible(print(cmp))
  expect_false(out$visible)
  expect_identical(out$value, cmp)
})

test_that("print.summary renders the dataCompareR report layout", {
  out <- capture.output(print(summary(rCompare(rc_a, rc_b, keys = "id"))))
  expect_match(out, "^Data Comparison$", all = FALSE)
  expect_match(out, "^Meta Summary$", all = FALSE)
  expect_match(out, "^Variable Summary$", all = FALSE)
  expect_match(out, "^Row Summary$", all = FALSE)
  expect_match(out, "^Data Values Comparison Summary$", all = FALSE)
  expect_match(out, "^Unequal column details$", all = FALSE)
  expect_match(out, "Number of columns in common: 3", all = FALSE)
  expect_match(out, "Match keys", all = FALSE)
  expect_match(out, "\\|Dataset Name", all = FALSE)
  expect_match(out, "#### Column - +VAL", all = FALSE)
  expect_match(out, "With datadiffr version", all = FALSE)
})

test_that("print.summary handles an all-equal comparison", {
  a <- data.frame(x = 1:2)
  out <- capture.output(print(summary(rCompare(a, a))))
  expect_match(
    out,
    "Number of columns compared with ALL rows equal: 1",
    all = FALSE
  )
  expect_no_match(out, "Unequal column details")
})

test_that("summary validates mismatchCount", {
  cmp <- rCompare(rc_a, rc_b, keys = "id")
  expect_error(summary(cmp, mismatchCount = 0))
  expect_error(summary(cmp, mismatchCount = -1))
})
