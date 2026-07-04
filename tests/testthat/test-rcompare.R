# rCompare() is a clean-room reimplementation of the dataCompareR contract.
# Object shapes and semantics below were pinned empirically against
# dataCompareR 0.1.4 (see test-rcompare-parity.R for the live oracle tests).
# Fixtures rc_a / rc_b come from helper-rcompare.R.

test_that("rCompare returns a classed compatibility object", {
  cmp <- rCompare(rc_a, rc_b, keys = "id")
  expect_s3_class(cmp, "datadiff_compare")
  expect_s3_class(cmp, "dataCompareRobject")
  expect_named(
    cmp,
    c(
      "meta",
      "colMatching",
      "rowMatching",
      "cleaninginfo",
      "mismatches",
      "matches"
    )
  )
})

test_that("meta records input names, dimensions, and call", {
  cmp <- rCompare(rc_a, rc_b, keys = "id")
  expect_named(
    cmp$meta,
    c("args", "runTimestamp", "A", "B", "objVersion", "roundDigits")
  )
  expect_identical(cmp$meta$A, list(name = "rc_a", rows = 4L, cols = 4L))
  expect_identical(cmp$meta$B, list(name = "rc_b", rows = 4L, cols = 4L))
  expect_true(is.call(cmp$meta$args))
  expect_s3_class(cmp$meta$runTimestamp, "POSIXct")
  expect_identical(cmp$meta$objVersion, 1)
  expect_identical(cmp$meta$roundDigits, NA)
})

test_that("colMatching reports shared columns uppercased and sorted", {
  cmp <- rCompare(rc_a, rc_b, keys = "id")
  expect_identical(cmp$colMatching$inboth, c("CHR", "ID", "VAL"))
  expect_identical(cmp$colMatching$inA, "only_a")
  expect_identical(cmp$colMatching$inB, "only_b")
})

test_that("column matching is case-insensitive after make.names cleaning", {
  a <- data.frame(1:2, 3:4)
  names(a) <- c("Val One", "x")
  b <- data.frame(1:2, 3:4)
  names(b) <- c("val one", "x")
  cmp <- rCompare(a, b)
  expect_identical(cmp$colMatching$inboth, c("VAL.ONE", "X"))
})

test_that("keyed rowMatching reports match keys and per-side key values", {
  cmp <- rCompare(rc_a, rc_b, keys = "id")
  expect_named(cmp$rowMatching, c("matchKeys", "inboth", "inA", "inB"))
  expect_identical(cmp$rowMatching$matchKeys, "ID")
  expect_equal(cmp$rowMatching$inboth, data.frame(ID = 1:3))
  expect_identical(cmp$rowMatching$inA, list(ID = 4L))
  expect_identical(cmp$rowMatching$inB, list(ID = 5L))
})

test_that("keyless rowMatching matches by position and truncates the longer frame", {
  a <- data.frame(v = 1:5)
  b <- data.frame(v = c(1L, 2L, 9L))
  cmp <- rCompare(a, b)
  expect_identical(cmp$rowMatching$matchKeys, NA_character_)
  expect_identical(cmp$rowMatching$inboth, 1:3)
  expect_identical(cmp$rowMatching$inA, list(indices_removed = 4:5))
  expect_identical(cmp$rowMatching$inB, list(indices_removed = integer()))
})

test_that("mismatches holds one table per differing column, keyed and typed", {
  cmp <- rCompare(rc_a, rc_b, keys = "id")
  expect_s3_class(cmp$mismatches, "mismatches")
  expect_named(cmp$mismatches, c("CHR", "VAL"))
  expect_named(
    cmp$mismatches$VAL,
    c("ID", "valueA", "valueB", "variable", "typeA", "typeB", "diffAB")
  )
  expect_equal(
    cmp$mismatches$VAL,
    data.frame(
      ID = 2L,
      valueA = 2,
      valueB = 2.5,
      variable = "VAL",
      typeA = "double",
      typeB = "double",
      diffAB = -0.5
    ),
    ignore_attr = TRUE
  )
  expect_identical(cmp$mismatches$CHR$diffAB, "")
})

test_that("keyless mismatch tables carry no key columns", {
  a <- data.frame(v = 1:3, w = c("x", "y", "z"))
  b <- data.frame(v = c(1L, 9L, 3L), w = c("x", "y", "z"))
  cmp <- rCompare(a, b)
  expect_named(
    cmp$mismatches$V,
    c("valueA", "valueB", "variable", "typeA", "typeB", "diffAB")
  )
  expect_identical(cmp$mismatches$V$diffAB, -7L)
})

test_that("matches lists fully-equal shared columns, excluding keys", {
  a <- data.frame(id = 1:3, same = c("x", "y", "z"), diff = 1:3)
  b <- data.frame(id = 1:3, same = c("x", "y", "z"), diff = c(1L, 9L, 3L))
  cmp <- rCompare(a, b, keys = "id")
  expect_s3_class(cmp$matches, "matches")
  expect_identical(as.character(cmp$matches), "SAME")
  expect_named(cmp$mismatches, "DIFF")
})

test_that("identical frames yield all matches and an empty mismatches list", {
  a <- data.frame(x = 1:2, y = c("a", "b"))
  cmp <- rCompare(a, a)
  expect_identical(as.character(cmp$matches), c("X", "Y"))
  expect_length(cmp$mismatches, 0)
  expect_s3_class(cmp$mismatches, "mismatches")
  expect_named(cmp$mismatches)
})

test_that("keyed mismatch tables are ordered by key", {
  a <- data.frame(id = c(3L, 1L, 2L), v = c(30L, 10L, 20L))
  b <- data.frame(id = c(2L, 3L, 1L), v = c(21L, 31L, 11L))
  cmp <- rCompare(a, b, keys = "id")
  expect_identical(cmp$mismatches$V$ID, 1:3)
  expect_identical(cmp$mismatches$V$valueA, c(10L, 20L, 30L))
  expect_equal(cmp$rowMatching$inboth, data.frame(ID = 1:3))
})

test_that("multiple keys are supported", {
  a <- data.frame(k1 = c(1, 1, 2), k2 = c("a", "b", "a"), v = 1:3)
  b <- data.frame(k1 = c(1, 1, 2), k2 = c("a", "b", "a"), v = c(1L, 9L, 3L))
  cmp <- rCompare(a, b, keys = c("k1", "k2"))
  expect_identical(cmp$rowMatching$matchKeys, c("K1", "K2"))
  expect_equal(
    cmp$rowMatching$inboth,
    data.frame(K1 = c(1, 1, 2), K2 = c("a", "b", "a"))
  )
  expect_identical(
    names(cmp$mismatches$V),
    c("K1", "K2", "valueA", "valueB", "variable", "typeA", "typeB", "diffAB")
  )
  expect_identical(cmp$mismatches$V$K2, "b")
})

test_that("duplicate key values error", {
  a <- data.frame(id = c(1, 1), v = 1:2)
  expect_error(rCompare(a, a, keys = "id"), "uniquely identify")
})

test_that("keys missing from either frame error", {
  a <- data.frame(id = 1, v = 1)
  b <- data.frame(v = 2)
  expect_error(rCompare(a, b, keys = "id"), "id")
  # key validation is case-sensitive against cleaned names, as in dataCompareR
  expect_error(rCompare(a, a, keys = "ID"), "ID")
})

test_that("NA matches NA, NaN matches NaN, but NA does not match NaN", {
  a <- data.frame(v = c(NA, NaN, NA, 1))
  b <- data.frame(v = c(NA, NaN, NaN, NA))
  cmp <- rCompare(a, b)
  expect_identical(nrow(cmp$mismatches$V), 2L)
  expect_identical(cmp$mismatches$V$valueB, c(NaN, NA))
})

test_that("columns with mismatched classes report every row with blank diffAB", {
  a <- data.frame(id = 1:3, v = c(1L, 2L, 3L))
  b <- data.frame(id = 1:3, v = c(1.0, 2.0, 3.5))
  cmp <- rCompare(a, b, keys = "id")
  expect_length(cmp$matches, 0)
  expect_identical(nrow(cmp$mismatches$V), 3L)
  expect_identical(cmp$mismatches$V$typeA, rep("integer", 3))
  expect_identical(cmp$mismatches$V$typeB, rep("double", 3))
  expect_identical(cmp$mismatches$V$diffAB, rep("", 3))
})

test_that("factors are compared as character and recorded in cleaninginfo", {
  a <- data.frame(id = 1:2, f = factor(c("u", "v")))
  b <- data.frame(id = 1:2, f = c("u", "w"), stringsAsFactors = FALSE)
  cmp <- rCompare(a, b, keys = "id")
  expect_s3_class(cmp$cleaninginfo, "cleaninginfo")
  expect_identical(
    cmp$cleaninginfo$F,
    c("factor", "character", "character", "character")
  )
  expect_identical(cmp$mismatches$F$valueA, "v")
  expect_identical(cmp$mismatches$F$typeA, "character")
})

test_that("cleaninginfo is an empty classed list when nothing was coerced", {
  cmp <- rCompare(rc_a, rc_b, keys = "id")
  expect_s3_class(cmp$cleaninginfo, "cleaninginfo")
  expect_length(cmp$cleaninginfo, 0)
})

test_that("trimChars trims character columns before comparing", {
  a <- data.frame(s = c("x ", " y"), stringsAsFactors = FALSE)
  b <- data.frame(s = c("x", "y"), stringsAsFactors = FALSE)
  expect_identical(nrow(rCompare(a, b)$mismatches$S), 2L)
  cmp <- rCompare(a, b, trimChars = TRUE)
  expect_identical(as.character(cmp$matches), "S")
  expect_length(cmp$mismatches, 0)
})

test_that("roundDigits rounds numeric columns before comparing", {
  a <- data.frame(v = c(1.14, 2.26))
  b <- data.frame(v = c(1.11, 2.29))
  cmp <- rCompare(a, b, roundDigits = 1)
  expect_identical(as.character(cmp$matches), "V")
  expect_identical(cmp$meta$roundDigits, 1)
  cmp2 <- rCompare(a, b, roundDigits = 2)
  expect_identical(nrow(cmp2$mismatches$V), 2L)
})

test_that("the mismatches cap errors when total mismatch rows exceed it", {
  a <- data.frame(p = 1:2, q = 1:2)
  b <- data.frame(p = c(1L, 9L), q = c(9L, 2L))
  # one mismatch in each of two columns: 2 total, strictly greater than cap 1
  expect_error(rCompare(a, b, mismatches = 1), "exceeds")
  expect_no_error(rCompare(a, b, mismatches = 2))
  expect_error(rCompare(a, b, mismatches = 0))
})

test_that("frames with no shared columns return an object, not an error", {
  cmp <- rCompare(data.frame(a = 1), data.frame(b = 1))
  expect_identical(cmp$colMatching$inboth, character())
  expect_length(cmp$matches, 0)
  expect_length(cmp$mismatches, 0)
})

test_that("tolerance extension treats close numeric values as equal", {
  a <- data.frame(v = c(1.00, 2.00))
  b <- data.frame(v = c(1.04, 2.50))
  cmp <- rCompare(a, b, tolerance = 0.1)
  expect_identical(nrow(cmp$mismatches$V), 1L)
  expect_identical(cmp$mismatches$V$valueB, 2.5)
})

test_that("tibbles are accepted and object internals are plain data frames", {
  a <- tibble(id = 1:2, v = c(1, 2))
  b <- tibble(id = 1:2, v = c(1, 9))
  cmp <- rCompare(a, b, keys = "id")
  expect_identical(class(cmp$mismatches$V), "data.frame")
  expect_equal(cmp$rowMatching$inboth, data.frame(ID = 1:2))
})

test_that("rCompare validates its arguments", {
  a <- data.frame(x = 1)
  expect_error(rCompare(1:3, a))
  expect_error(rCompare(a, a, keys = 1))
  expect_error(rCompare(a, a, roundDigits = "a"))
  expect_error(rCompare(a, a, trimChars = NA))
  expect_error(rCompare(a, a, tolerance = -1))
})
