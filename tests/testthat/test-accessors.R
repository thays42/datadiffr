# Accessors: the supported programmatic surface of a datadiff_result, so user
# code never reaches into the object's attributes or bookkeeping columns.

test_that("has_differences reports each result kind", {
  x <- tibble(a = 1:3)

  expect_false(has_differences(compare_data(x, x)))
  expect_true(has_differences(compare_data(x, tibble(a = c(1L, 9L, 3L)))))
  expect_true(has_differences(compare_data(x, tibble(b = 1:3))))
})

test_that("n_differences counts differing rows", {
  x <- tibble(a = 1:4)
  y <- tibble(a = c(1L, 9L, 3L, 8L))

  expect_identical(n_differences(compare_data(x, y)), 2L)
  expect_identical(n_differences(compare_data(x, x)), 0L)
})

test_that("n_differences is NA for schema results", {
  result <- compare_data(tibble(a = 1), tibble(b = 1))

  expect_identical(n_differences(result), NA_integer_)
})

test_that("n_differences counts all differing rows even when truncated", {
  x <- tibble(a = 1:5)
  y <- tibble(a = c(9L, 8L, 7L, 6L, 5L))

  result <- suppressMessages(compare_data(x, y, max_differences = 2))

  # rows 1-4 differ (5 == 5 does not); the cap truncates reporting, not the count
  expect_identical(n_differences(result), 4L)
})

test_that("get_differences returns differing rows without context", {
  x <- tibble(id = 1:4, score = c(10, 20, 30, 40))
  y <- tibble(id = 1:4, score = c(10, 25, 30, 40))

  out <- get_differences(compare_data(x, y))

  expect_s3_class(out, "tbl_df")
  expect_false(inherits(out, "datadiff_diff"))
  expect_named(out, c(".row", ".source", "id", "score"))
  expect_setequal(out$.row, 2L)
  expect_setequal(out$.source, c("x", "y"))
})

test_that("get_differences filters rows by selected columns", {
  x <- tibble(
    id = 1:4,
    score = c(10, 20, 30, 40),
    name = c("ann", "bob", "cara", "dan")
  )
  y <- tibble(
    id = 1:4,
    score = c(10, 25, 30, 40),
    name = c("ann", "bob", "cara", "dana")
  )
  result <- compare_data(x, y)

  expect_setequal(get_differences(result)$.row, c(2L, 4L))
  expect_setequal(get_differences(result, columns = score)$.row, 2L)
  expect_setequal(get_differences(result, columns = name)$.row, 4L)
})

test_that("get_differences keeps one-sided rows under any column selection", {
  x <- tibble(id = 1:3, score = c(10, 20, 30))
  y <- tibble(id = 1:2, score = c(10, 20))

  out <- get_differences(compare_data(x, y), columns = score)

  expect_equal(out$.row, 3L)
  expect_equal(out$.source, "x")
})

test_that("get_differences preserves native column types", {
  x <- tibble(id = 1:3, when = as.Date("2026-01-01") + 0:2)
  y <- tibble(id = 1:3, when = as.Date("2026-01-01") + c(0, 9, 2))

  out <- get_differences(compare_data(x, y))

  expect_s3_class(out$when, "Date")
})

test_that("get_differences on an identical result is an empty stable tibble", {
  x <- tibble(id = 1:3, score = c(1, 2, 3))

  out <- get_differences(compare_data(x, x))

  expect_identical(nrow(out), 0L)
  expect_named(out, c(".row", ".source", "id", "score"))
})

test_that("get_differences errors on schema results with guidance", {
  result <- compare_data(tibble(a = 1), tibble(b = 1))

  expect_error(get_differences(result), "schema")
})

test_that("get_cell_differences returns one row per differing cell", {
  x <- tibble(
    id = 1:4,
    score = c(10, 20, 30, 40),
    name = c("ann", "bob", "cara", "dan")
  )
  y <- tibble(
    id = 1:4,
    score = c(10, 25, 30, 40),
    name = c("ann", "bob", "cara", "dana")
  )

  out <- get_cell_differences(compare_data(x, y))

  expect_named(out, c(".row", ".column", ".value_x", ".value_y"))
  expect_equal(nrow(out), 2L)
  expect_equal(out$.row, c(2L, 4L))
  expect_equal(out$.column, c("score", "name"))
  expect_equal(out$.value_x, c("20", "dan"))
  expect_equal(out$.value_y, c("25", "dana"))
})

test_that("get_cell_differences includes key columns under keyed comparison", {
  x <- tibble(id = c("a", "b", "c"), score = 1:3)
  y <- tibble(id = c("a", "b", "c"), score = c(1L, 9L, 3L))

  out <- get_cell_differences(compare_data(x, y, by = "id"))

  expect_named(out, c(".row", "id", ".column", ".value_x", ".value_y"))
  expect_equal(out$id, "b")
  expect_equal(out$.column, "score")
})

test_that("get_cell_differences handles a key column named 'column'", {
  x <- tibble(column = c("a", "b"), score = c(1, 2))
  y <- tibble(column = c("a", "b"), score = c(1, 9))

  out <- get_cell_differences(compare_data(x, y, by = "column"))

  expect_named(out, c(".row", "column", ".column", ".value_x", ".value_y"))
  expect_equal(out$column, "b")
  expect_equal(out$.column, "score")
})

test_that("one-sided rows appear with NA on the missing side", {
  x <- tibble(id = 1:3, score = c(10, 20, 30))
  y <- tibble(id = 1:2, score = c(10, 20))

  out <- get_cell_differences(compare_data(x, y))
  row3 <- out[out$.row == 3L, ]

  expect_setequal(row3$.column, c("id", "score"))
  expect_true(all(is.na(row3$.value_y)))
  expect_equal(row3$.value_x[row3$.column == "score"], "30")
})

test_that("get_cell_differences respects the comparison tolerance", {
  x <- tibble(a = c(1, 2))
  y <- tibble(a = c(1.05, 3))

  out <- get_cell_differences(compare_data(x, y, tolerance = 0.1))

  expect_equal(out$.row, 2L)
  expect_equal(nrow(out), 1L)
})

test_that("get_cell_differences filters cells by selected columns", {
  x <- tibble(score = c(10, 20), name = c("ann", "bob"))
  y <- tibble(score = c(11, 20), name = c("ann", "rob"))
  result <- compare_data(x, y)

  out <- get_cell_differences(result, columns = name)

  expect_equal(out$.column, "name")
  expect_equal(out$.row, 2L)
})

test_that("get_cell_differences is empty-but-stable for identical frames", {
  x <- tibble(id = 1:3, score = c(1, 2, 3))

  out <- get_cell_differences(compare_data(x, x))

  expect_identical(nrow(out), 0L)
  expect_named(out, c(".row", ".column", ".value_x", ".value_y"))
})

test_that("get_cell_differences errors on schema results", {
  result <- compare_data(tibble(a = 1), tibble(b = 1))

  expect_error(get_cell_differences(result), "schema")
})

test_that("column selections with no matching differences return zero rows", {
  x <- tibble(a = c(1, 2), b = c("p", "q"))
  y <- tibble(a = c(1, 9), b = c("p", "q"))
  result <- compare_data(x, y)

  expect_identical(nrow(get_differences(result, columns = b)), 0L)
  expect_identical(nrow(get_cell_differences(result, columns = b)), 0L)
})

test_that("get_differences returns only the reported rows of a truncated result", {
  x <- tibble(a = 1:5)
  y <- tibble(a = c(9L, 8L, 7L, 6L, 5L))
  result <- suppressMessages(compare_data(x, y, max_differences = 2))

  out <- get_differences(result)

  expect_setequal(out$.row, c(1L, 2L))
})

test_that("frames sharing only key columns yield rows but no cells", {
  x <- tibble(id = 1:3)
  y <- tibble(id = c(1:2, 4L))
  result <- compare_data(x, y, by = "id")

  rows <- get_differences(result)
  cells <- get_cell_differences(result)

  expect_setequal(rows$.row, c(3L, 4L))
  expect_identical(nrow(cells), 0L)
})

test_that("cell values render with full precision and no padding", {
  x <- tibble(a = 1.00000001)
  y <- tibble(a = 1.00000002)

  out <- get_cell_differences(compare_data(x, y, tolerance = 0))

  expect_false(out$.value_x == out$.value_y)
})
