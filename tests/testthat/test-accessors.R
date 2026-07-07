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
