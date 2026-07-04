# Field-by-field parity between datadiffr::rCompare() and the archived
# dataCompareR package (kept in Suggests as a behavioral oracle).

oracle_rcompare <- function(...) {
  suppressMessages(suppressWarnings(dataCompareR::rCompare(...)))
}

# dataCompareR was archived from CRAN and calls dplyr functions (e.g.
# select_()) that are defunct in current dplyr, so an installed copy may no
# longer run. Skip parity checks unless the oracle is both installed and still
# functional against the dplyr on this machine.
skip_unless_oracle <- function() {
  skip_if_not_installed("dataCompareR")
  ok <- tryCatch(
    {
      oracle_rcompare(
        data.frame(id = 1:2, v = c(1, 2)),
        data.frame(id = 1:2, v = c(1, 3)),
        keys = "id"
      )
      TRUE
    },
    error = function(e) FALSE
  )
  if (!ok) {
    skip("dataCompareR does not run against the installed dplyr")
  }
}

# empty per-side key vectors: the oracle's incidental types (e.g. logical(0))
# are not part of the contract, only their emptiness is
normalize_side <- function(x) {
  lapply(x, function(v) if (length(v) == 0) NULL else v)
}

strip_rownames <- function(df) {
  rownames(df) <- NULL
  df
}

expect_parity <- function(dfA, dfB, ...) {
  ours <- rCompare(dfA, dfB, ...)
  ref <- oracle_rcompare(dfA, dfB, ...)

  expect_identical(ours$colMatching, ref$colMatching)
  expect_identical(as.character(ours$matches), as.character(ref$matches))

  expect_identical(names(ours$mismatches), names(ref$mismatches))
  for (nm in names(ref$mismatches)) {
    expect_equal(
      strip_rownames(ours$mismatches[[nm]]),
      strip_rownames(ref$mismatches[[nm]]),
      ignore_attr = TRUE
    )
  }

  expect_identical(ours$rowMatching$matchKeys, ref$rowMatching$matchKeys)
  expect_equal(
    ours$rowMatching$inboth,
    ref$rowMatching$inboth,
    ignore_attr = TRUE
  )
  expect_equal(
    normalize_side(ours$rowMatching$inA),
    normalize_side(ref$rowMatching$inA),
    ignore_attr = TRUE
  )
  expect_equal(
    normalize_side(ours$rowMatching$inB),
    normalize_side(ref$rowMatching$inB),
    ignore_attr = TRUE
  )

  expect_equal(
    unclass(ours$cleaninginfo),
    unclass(ref$cleaninginfo),
    ignore_attr = TRUE
  )

  expect_identical(ours$meta$A$rows, ref$meta$A$rows)
  expect_identical(ours$meta$B$rows, ref$meta$B$rows)
  expect_identical(ours$meta$A$cols, ref$meta$A$cols)
  expect_identical(ours$meta$B$cols, ref$meta$B$cols)
  expect_identical(ours$meta$roundDigits, ref$meta$roundDigits)

  invisible(NULL)
}

test_that("parity: keyed comparison with one-sided columns and rows", {
  skip_unless_oracle()
  dfa <- data.frame(
    id = 1:4,
    val = c(1, 2, 3, 4),
    chr = c("a", "b", "c", "d"),
    only_a = c(TRUE, FALSE, TRUE, FALSE)
  )
  dfb <- data.frame(
    id = c(1L, 2L, 3L, 5L),
    val = c(1, 2.5, 3, 4),
    chr = c("a", "B", "c", "e"),
    only_b = 1:4
  )
  expect_parity(dfa, dfb, keys = "id")
})

test_that("parity: keyless comparison with truncation", {
  skip_unless_oracle()
  expect_parity(
    data.frame(v = 1:5, w = letters[1:5]),
    data.frame(v = c(1L, 2L, 9L), w = c("a", "x", "c"))
  )
})

test_that("parity: multiple keys", {
  skip_unless_oracle()
  a <- data.frame(k1 = c(1, 1, 2, 3), k2 = c("a", "b", "a", "z"), v = 1:4)
  b <- data.frame(
    k1 = c(1, 1, 2, 4),
    k2 = c("a", "b", "a", "q"),
    v = c(1L, 9L, 3L, 4L)
  )
  expect_parity(a, b, keys = c("k1", "k2"))
})

test_that("parity: unsorted keys are reported in key order", {
  skip_unless_oracle()
  a <- data.frame(id = c(3L, 1L, 2L), v = c(30L, 10L, 20L))
  b <- data.frame(id = c(2L, 3L, 1L), v = c(21L, 31L, 11L))
  expect_parity(a, b, keys = "id")
})

test_that("parity: factors, NA/NaN handling, and type-mismatched columns", {
  skip_unless_oracle()
  a <- data.frame(
    id = 1:4,
    f = factor(c("u", "v", "u", "w")),
    n = c(NA, NaN, NA, 1),
    t = c(1L, 2L, 3L, 4L)
  )
  b <- data.frame(
    id = 1:4,
    f = c("u", "w", "u", "w"),
    n = c(NA, NaN, NaN, NA),
    t = c(1.0, 2.0, 3.0, 4.5)
  )
  expect_parity(a, b, keys = "id")
})

test_that("parity: trimChars and roundDigits", {
  skip_unless_oracle()
  a <- data.frame(s = c("x ", " y", "z"), v = c(1.14, 2.26, 3.5))
  b <- data.frame(s = c("x", "y", "z"), v = c(1.11, 2.29, 3.5))
  expect_parity(a, b, trimChars = TRUE, roundDigits = 1)
  expect_parity(a, b)
})

test_that("parity: identical frames", {
  skip_unless_oracle()
  a <- data.frame(x = 1:3, y = c("a", "b", "c"))
  expect_parity(a, a)
})

test_that("parity: column name cleaning and case-insensitive matching", {
  skip_unless_oracle()
  a <- data.frame(1:2, 3:4, 5:6)
  names(a) <- c("Val One", "x", "extra")
  b <- data.frame(1:2, 3:4)
  names(b) <- c("val one", "X")
  expect_parity(a, b)
})
