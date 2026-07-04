# The classed diff object returned by compare_data(): carries the tolerance,
# truncation state, and changed columns so downstream code (notably the
# renderer) never has to re-derive them. Fixes B11.

test_that("compare_data returns a datadiff_diff object", {
  x <- tibble(a = 1:3)
  y <- tibble(a = c(1L, 9L, 3L))

  result <- compare_data(x, y, context_rows = c(0L, 0L))

  expect_s3_class(result, "datadiff_diff")
  expect_s3_class(result, "tbl_df")
  expect_true(is.data.frame(result))
})

test_that("an empty diff is still a datadiff_diff object", {
  x <- tibble(a = 1:3)

  result <- compare_data(x, x)

  expect_s3_class(result, "datadiff_diff")
  expect_equal(nrow(result), 0L)
})

test_that("the diff object records the tolerance used", {
  x <- tibble(a = c(1, 2, 3))
  y <- tibble(a = c(1, 9, 3))

  result <- compare_data(x, y, context_rows = c(0L, 0L), tolerance = 0.25)

  expect_equal(attr(result, "tolerance"), 0.25)
})

test_that("the diff object records which columns changed", {
  x <- tibble(a = 1:3, b = c(10L, 20L, 30L), c = letters[1:3])
  y <- tibble(a = 1:3, b = c(10L, 99L, 30L), c = letters[1:3])

  result <- compare_data(x, y, context_rows = c(0L, 0L))

  expect_equal(attr(result, "diff_columns"), "b")
})

test_that("the diff object records the total differences and truncation", {
  x <- tibble(a = 1:4)
  y <- tibble(a = c(9L, 8L, 7L, 6L))

  full <- compare_data(x, y, context_rows = c(0L, 0L))
  expect_equal(attr(full, "n_differences"), 4L)
  expect_false(attr(full, "truncated"))

  expect_message(
    capped <- compare_data(x, y, context_rows = c(0L, 0L), max_differences = 2)
  )
  expect_equal(attr(capped, "n_differences"), 4L)
  expect_true(attr(capped, "truncated"))
})

test_that("print.datadiff_diff shows a summary header and returns invisibly", {
  x <- tibble(a = 1:3, b = c(10L, 20L, 30L))
  y <- tibble(a = c(1L, 9L, 3L), b = c(10L, 20L, 30L))

  result <- compare_data(x, y, context_rows = c(0L, 0L))

  expect_output(print(result), "changed")
  expect_invisible(print(result))
})

test_that("summary.datadiff_diff counts changed, added, and removed rows", {
  x <- tibble(id = c(1, 2, 3), v = c("a", "b", "c"))
  y <- tibble(id = c(2, 3, 4), v = c("b", "XX", "d"))

  result <- compare_data(x, y, by = "id", context_rows = c(0L, 0L))
  s <- summary(result)

  expect_equal(s$rows_changed, 1L) # id 3 differs
  expect_equal(s$rows_removed, 1L) # id 1 only in x
  expect_equal(s$rows_added, 1L) # id 4 only in y
  expect_equal(s$columns_changed, "v")
  expect_equal(s$tolerance, attr(result, "tolerance"))
})

test_that("show_diff honors the diff object's tolerance (B11)", {
  # a differs beyond tolerance (row 2); b differs only within tolerance and so
  # must not be coloured as a difference.
  x <- tibble(a = c(1, 2), b = c(10, 20))
  y <- tibble(a = c(1, 9), b = c(10, 20.05))

  diff <- compare_data(x, y, context_rows = c(0L, 0L), tolerance = 0.1)
  html <- as.character(show_diff(diff))

  red <- lengths(regmatches(html, gregexpr("color:red", html)))
  green <- lengths(regmatches(html, gregexpr("color:green", html)))

  # only column a (2 vs 9) should be coloured: one red cell, one green cell
  expect_equal(red, 1L)
  expect_equal(green, 1L)
})
