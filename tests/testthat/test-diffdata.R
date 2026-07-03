test_that("diffdata validates inputs correctly", {
  # Valid inputs should work
  df1 <- tibble(a = 1:5, b = letters[1:5])
  df2 <- tibble(a = c(1:4, 6), b = letters[1:5])

  # Test x must be a tibble
  expect_error(diffdata("not_a_dataframe", df2), "x must be a data frame")
  expect_error(diffdata(NULL, df2), "x must be a data frame")
  expect_error(diffdata(list(a = 1:5), df2), "x must be a data frame")

  # Test y must be a tibble
  expect_error(diffdata(df1, "not_a_dataframe"), "y must be a data frame")
  expect_error(diffdata(df1, NULL), "y must be a data frame")

  # Test x must have at least one row
  expect_error(
    diffdata(tibble(), df2),
    "x must have at least one row"
  )

  # Test y must have at least one row
  expect_error(
    diffdata(df1, tibble()),
    "y must have at least one row"
  )

  # Test max_differences must be numeric and length 1
  expect_error(
    diffdata(df1, df2, max_differences = "ten"),
    "max_differences must be numeric"
  )
  expect_error(
    diffdata(df1, df2, max_differences = 1:3),
    "max_differences must be length 1"
  )

  # Test context_rows must be numeric and length 2
  expect_error(
    diffdata(df1, df2, context_rows = "three"),
    "context_rows must be numeric"
  )
  expect_error(
    diffdata(df1, df2, context_rows = 1:3),
    "context_rows must be length 2"
  )
  expect_error(
    diffdata(df1, df2, context_rows = 3),
    "context_rows must be length 2"
  )

  # Test column differences handling
  df3 <- tibble(a = 1:5, c = letters[1:5]) # different column names
  expect_message(
    result <- diffdata(df1, df3),
    "Cannot diff data with column differences."
  )

  expect_true(is.data.frame(result))
  expect_true(".diff" %in% names(result))
})

test_that("diffdata handles edge cases", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc not available")

  # Test with minimal tibbles
  df_min1 <- tibble(a = 1)
  df_min2 <- tibble(a = 2)
  expect_no_error(diffdata(df_min1, df_min2))

  # Test with integer context_rows through the diff path
  df1 <- tibble(a = 1:5, b = letters[1:5])
  df2 <- tibble(a = c(1:4, 6L), b = letters[1:5])
  result <- diffdata(df1, df2, context_rows = c(0L, 0L))
  expect_equal(unique(result$.row), 5)

  result_ctx <- diffdata(df1, df2, context_rows = c(10L, 5L))
  expect_equal(sort(unique(result_ctx$.row)), 1:5)
})

test_that("diffdata reports no differences for identical data frames", {
  df <- tibble(a = 1:3, b = letters[1:3])

  expect_message(result <- diffdata(df, df), "[Nn]o differences")
  expect_equal(nrow(result), 0)
})

test_that("render_diff handles an empty diff without error", {
  df <- tibble(a = 1:3)
  empty <- compare_data(df, df)

  expect_message(result <- render_diff(empty), "[Nn]o differences")
  expect_null(result)
})

test_that("diffdata writes output_file and passes bare context_cols through", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc not available")

  x <- tibble(id = 1:3, a = c(1, 5, 3))
  y <- tibble(id = 1:3, a = c(1, 2, 3))
  out <- withr::local_tempfile(fileext = ".html")

  result <- diffdata(x, y, context_cols = id, output_file = out)

  expect_true(file.exists(out))
  expect_true("id" %in% names(result))
})

test_that("render_diff errors when the output_file directory does not exist", {
  df1 <- tibble(a = 1)
  df2 <- tibble(a = 2)
  diff <- compare_data(df1, df2)

  expect_error(
    render_diff(diff, output_file = "/nonexistent-datadiff-dir/report.html"),
    "output_file"
  )
})
