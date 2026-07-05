test_that("diffdata validates x and y", {
  df1 <- tibble(a = 1:5, b = letters[1:5])
  df2 <- tibble(a = c(1:4, 6), b = letters[1:5])

  expect_error(diffdata("not_a_dataframe", df2), "'x'.*data.frame")
  expect_error(diffdata(NULL, df2), "'x'.*data.frame")
  expect_error(diffdata(list(a = 1:5), df2), "'x'.*data.frame")
  expect_error(diffdata(df1, "not_a_dataframe"), "'y'.*data.frame")
  expect_error(diffdata(df1, NULL), "'y'.*data.frame")

  expect_error(diffdata(tibble(), df2), "'x'.*at least 1 row")
  expect_error(diffdata(df1, tibble()), "'y'.*at least 1 row")
})

test_that("diffdata validates max_differences", {
  df1 <- tibble(a = 1:5)
  df2 <- tibble(a = c(1:4, 6L))

  expect_error(
    diffdata(df1, df2, max_differences = "ten"),
    "'max_differences'.*number"
  )
  expect_error(
    diffdata(df1, df2, max_differences = 1:3),
    "'max_differences'.*length 1"
  )
  expect_error(
    diffdata(df1, df2, max_differences = -1),
    "'max_differences'.*>= 0"
  )
})

test_that("diffdata validates context_rows", {
  df1 <- tibble(a = 1:5)
  df2 <- tibble(a = c(1:4, 6L))

  expect_error(
    diffdata(df1, df2, context_rows = "three"),
    "'context_rows'.*integerish"
  )
  expect_error(
    diffdata(df1, df2, context_rows = 1:3),
    "'context_rows'.*length 2"
  )
  expect_error(diffdata(df1, df2, context_rows = 3), "'context_rows'.*length 2")
  expect_error(
    diffdata(df1, df2, context_rows = c(-1L, 0L)),
    "'context_rows'.*>= 0"
  )
})

test_that("diffdata validates tolerance and output_file", {
  df1 <- tibble(a = 1:5)
  df2 <- tibble(a = c(1:4, 6L))

  expect_error(diffdata(df1, df2, tolerance = -1), "'tolerance'.*>= 0")
  expect_error(diffdata(df1, df2, tolerance = "0.1"), "'tolerance'.*number")
  expect_error(diffdata(df1, df2, output_file = 123), "'output_file'.*string")
})

test_that("diffdata returns a schema-kind result invisibly when columns differ", {
  df1 <- tibble(a = 1:5, b = letters[1:5])
  df3 <- tibble(a = 1:5, c = letters[1:5])

  expect_message(res <- diffdata(df1, df3), "[Cc]olumns differ")
  expect_invisible(suppressMessages(diffdata(df1, df3)))
  res <- suppressMessages(diffdata(df1, df3))
  expect_s3_class(res, "datadiff_result")
  expect_equal(res$kind, "schema")
  expect_true("in y only" %in% res$columns$.diff)
})

test_that("render_diff validates the diff argument", {
  expect_error(render_diff("nope"), "'diff'.*data.frame")
  expect_error(render_diff(tibble(a = 1)), "must include")
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
  expect_equal(unique(result$rows$.row), 5)

  result_ctx <- diffdata(df1, df2, context_rows = c(10L, 5L))
  expect_equal(sort(unique(result_ctx$rows$.row)), 1:5)
})

test_that("diffdata reports no differences", {
  df <- tibble(a = 1:5, b = letters[1:5])
  expect_message(res <- diffdata(df, df), "[Nn]o differences")
  res <- suppressMessages(diffdata(df, df))
  expect_s3_class(res, "datadiff_result")
  expect_equal(res$kind, "identical")
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
  expect_true("id" %in% names(result$rows))
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

test_that("diffdata and compare_data share argument order", {
  expect_equal(
    names(formals(diffdata)),
    c(names(formals(compare_data)), "output_file")
  )
})
