test_that("compare_columns returns empty on equal data frames", {
  expect_equal(nrow(compare_columns(example_types, example_types)), 0L)
})

test_that("compare_columns works on different data frames", {
  a <- example_types |>
    select(-datetimes)
  b <- example_types |>
    mutate(lgl = as.character(lgl)) |>
    select(-dates)

  actual <- compare_columns(a, b)
  # fmt: skip
  expected <- tribble(
    ~.diff, ~column, ~x_type, ~y_type,
    "in x only", "dates", "Date", NA_character_,
    "in y only", "datetimes", NA_character_, "POSIXct/POSIXt",
    "type conflict", "lgl", "logical", "character"
  )
  expect_equal(actual, expected)
})

test_that("compare_join works with equal dataframes", {
  df1 <- tibble(a = 1:3, b = letters[1:3])
  df2 <- tibble(a = 1:3, b = letters[1:3])

  result <- compare_join(df1, df2)

  expect_named(
    result,
    c(
      ".row",
      ".join_type",
      "a.__datadiff_x__",
      "b.__datadiff_x__",
      "a.__datadiff_y__",
      "b.__datadiff_y__"
    )
  )
  expect_equal(result$.join_type, rep("both", 3))
  expect_equal(result$.row, 1:3)
})

test_that("compare_join handles x longer than y", {
  df1 <- tibble(a = 1:5, b = letters[1:5])
  df2 <- tibble(a = 4:6, b = letters[4:6])

  result <- compare_join(df1, df2)

  expect_equal(nrow(result), 5)
  expect_equal(result$.join_type[1:3], rep("both", 3))
  expect_equal(result$.join_type[4:5], rep("x", 2))
})

test_that("compare_join handles y longer than x", {
  df1 <- tibble(a = 4:6, b = letters[4:6])
  df2 <- tibble(a = 1:5, b = letters[1:5])

  result <- compare_join(df1, df2)

  expect_equal(nrow(result), 5)
  expect_equal(result$.join_type[1:3], rep("both", 3))
  expect_equal(result$.join_type[4:5], rep("y", 2))
})

test_that("compare_join handles empty dataframes", {
  df1 <- tibble(a = numeric(0), b = character(0))
  df2 <- tibble(c = numeric(0), d = character(0))

  result <- compare_join(df1, df2)

  expect_equal(nrow(result), 0)
  expect_true(all(c(".row", ".join_type") %in% names(result)))
})

test_that("compare_groups works with equal dataframes", {
  df1 <- tibble(group = c("A", "B", "C"), value = 1:3)
  df2 <- tibble(group = c("A", "B", "C"), value = 4:6)

  result <- compare_groups(df1, df2, group)

  # Should return empty since all groups are in both dataframes
  expect_equal(nrow(result), 0)
  expect_named(result, c("group", "in_x", "in_y"))
})

test_that("compare_groups identifies groups only in x or y", {
  df1 <- tibble(group = c("A", "B", "C"), value = 1:3)
  df2 <- tibble(group = c("A", "D"), value = 4:5)

  result <- compare_groups(df1, df2, group)

  expected <- tibble(
    group = c("B", "C", "D"),
    in_x = c(TRUE, TRUE, FALSE),
    in_y = c(FALSE, FALSE, TRUE)
  )
  expect_equal(result, expected)
})

test_that("compare_groups identifies groups only in y", {
  df1 <- tibble(group = c("A", "B"), value = 1:2)
  df2 <- tibble(group = c("A", "C", "D"), value = 3:5)

  result <- compare_groups(df1, df2, group)

  expected <- tibble(
    group = c("B", "C", "D"),
    in_x = c(TRUE, FALSE, FALSE),
    in_y = c(FALSE, TRUE, TRUE)
  )
  expect_equal(result, expected)
})

test_that("compare_groups works with multiple grouping columns", {
  df1 <- tibble(
    group1 = c("A", "A", "B"),
    group2 = c("X", "Y", "X"),
    value = 1:3
  )
  df2 <- tibble(
    group1 = c("A", "B", "C"),
    group2 = c("X", "Y", "X"),
    value = 4:6
  )

  result <- compare_groups(df1, df2, c(group1, group2))

  expect_equal(nrow(result), 4)
  expect_equal(result$group1, c("A", "B", "B", "C"))
  expect_equal(result$group2, c("Y", "X", "Y", "X"))
  expect_equal(result$in_x, c(TRUE, TRUE, FALSE, FALSE))
  expect_equal(result$in_y, c(FALSE, FALSE, TRUE, TRUE))
})

test_that("compare_groups works with tidy-select syntax", {
  df1 <- tibble(
    group = c("A", "B", "C"),
    other = c("X", "Y", "Z"),
    value = 1:3
  )
  df2 <- tibble(
    group = c("A", "D"),
    other = c("X", "W"),
    value = 4:5
  )

  result <- compare_groups(df1, df2, starts_with("group"))

  expect_equal(nrow(result), 3)
  expect_equal(result$group, c("B", "C", "D"))
  expect_equal(result$in_x, c(TRUE, TRUE, FALSE))
  expect_equal(result$in_y, c(FALSE, FALSE, TRUE))
})

test_that("compare_groups handles empty dataframes", {
  df1 <- tibble(group = character(0), value = numeric(0))
  df2 <- tibble(group = c("A", "B"), value = 1:2)

  result <- compare_groups(df1, df2, group)

  expect_equal(nrow(result), 2)
  expect_equal(result$group, c("A", "B"))
  expect_equal(result$in_x, c(FALSE, FALSE))
  expect_equal(result$in_y, c(TRUE, TRUE))
})

test_that("compare_groups handles both empty dataframes", {
  df1 <- tibble(group = character(0), value = numeric(0))
  df2 <- tibble(group = character(0), value = numeric(0))

  result <- compare_groups(df1, df2, group)

  expect_equal(nrow(result), 0)
  expect_named(result, c("group", "in_x", "in_y"))
})

test_that("compare_groups works with multiple grouping columns (all unique)", {
  df1 <- tibble(
    group1 = c("A", "A", "B"),
    group2 = c("X", "Y", "X"),
    value = 1:3
  )
  df2 <- tibble(
    group1 = c("A", "B", "C"),
    group2 = c("X", "Y", "X"),
    value = 4:6
  )

  result <- compare_groups(df1, df2, c(group1, group2))

  expected <- tibble(
    group1 = c("A", "B", "B", "C"),
    group2 = c("Y", "X", "Y", "X"),
    in_x = c(TRUE, TRUE, FALSE, FALSE),
    in_y = c(FALSE, FALSE, TRUE, TRUE)
  )
  expect_equal(result, expected)
})

test_that("compare_groups works with tidy-select syntax (all unique)", {
  df1 <- tibble(
    group = c("A", "B", "C"),
    other = c("X", "Y", "Z"),
    value = 1:3
  )
  df2 <- tibble(
    group = c("A", "D"),
    other = c("X", "W"),
    value = 4:5
  )

  result <- compare_groups(df1, df2, starts_with("group"))

  expected <- tibble(
    group = c("B", "C", "D"),
    in_x = c(TRUE, TRUE, FALSE),
    in_y = c(FALSE, FALSE, TRUE)
  )
  expect_equal(result, expected)
})

test_that("compare_data respects tolerance parameter", {
  df1 <- tibble(a = c(1.0, 2.0, 3.0), b = c("x", "y", "z"))
  df2 <- tibble(a = c(1.001, 2.0, 3.0), b = c("x", "y", "z"))

  # With default tolerance, small difference should be detected
  result_default <- compare_data(df1, df2, context_rows = c(0L, 0L))
  expect_true(nrow(result_default) > 0)

  # With larger tolerance, difference should be ignored
  result_tolerant <- compare_data(
    df1,
    df2,
    context_rows = c(0L, 0L),
    tolerance = 0.01
  )
  expect_equal(nrow(result_tolerant), 0)
})

test_that("compare_data with tolerance handles multiple numeric columns", {
  df1 <- tibble(a = c(1.0, 2.0), b = c(10.0, 20.0))
  df2 <- tibble(a = c(1.0005, 2.0), b = c(10.0, 20.0005))

  # With tight tolerance, both columns should show differences
  result_tight <- compare_data(
    df1,
    df2,
    context_rows = c(0L, 0L),
    tolerance = 0.0001
  )
  expect_true(nrow(result_tight) > 0)

  # With loose tolerance, no differences
  result_loose <- compare_data(
    df1,
    df2,
    context_rows = c(0L, 0L),
    tolerance = 0.001
  )
  expect_equal(nrow(result_loose), 0)
})

test_that("compare_data handles columns ending in .x or .y", {
  # Columns named value.x and value.y should work correctly
  df1 <- tibble(value.x = 1:3, col = letters[1:3])
  df2 <- tibble(value.x = c(1L, 99L, 3L), col = letters[1:3])

  result <- compare_data(df1, df2, context_rows = c(0L, 0L))

  # Should detect the difference in value.x at row 2
  expect_true(nrow(result) > 0)
  expect_true("value.x" %in% names(result))

  # The difference should be at row 2
  diff_rows <- result[result$.diff_type == "diff", ]
  expect_true(all(diff_rows$.row == 2))
})

test_that("compare_join handles columns ending in .x or .y", {
  df1 <- tibble(value.x = 1:3, value.y = 4:6)
  df2 <- tibble(value.x = 1:3, value.y = 4:6)

  result <- compare_join(df1, df2)

  # Should have internal suffixes, not collision with user column names
  expect_true("value.x.__datadiff_x__" %in% names(result))
  expect_true("value.y.__datadiff_x__" %in% names(result))
  expect_true("value.x.__datadiff_y__" %in% names(result))
  expect_true("value.y.__datadiff_y__" %in% names(result))
})

test_that("compare_data reports added/deleted rows whose values are all NA", {
  x <- tibble(a = c(1, NA))
  y <- tibble(a = 1)

  result <- compare_data(x, y, context_rows = c(0L, 0L))

  expect_equal(result$.row, 2)
  expect_equal(result$.join_type, "x")
  expect_equal(result$.diff_type, "diff")
})

test_that("compare_data handles grouped data frames", {
  x <- tibble(g = c("a", "a", "b", "b"), v = 1:4) |> group_by(g)
  y <- tibble(g = c("a", "a", "b", "b"), v = c(1L, 9L, 3L, 4L)) |> group_by(g)

  result <- compare_data(x, y, context_rows = c(0L, 0L))

  expect_equal(unique(result$.row), 2)
  expect_equal(nrow(result), 2)
})

test_that("compare_data compares a user column named .rn", {
  x <- tibble(.rn = c(100, 200), a = 1:2)
  y <- tibble(.rn = c(100, 999), a = 1:2)

  result <- compare_data(x, y, context_rows = c(0L, 0L))

  expect_equal(unique(result$.row), 2)
  expect_true(".rn" %in% names(result))
  expect_setequal(result$.rn, c(200, 999))
})

test_that("compare_data errors clearly on type-conflicted columns", {
  x <- tibble(a = 1:3)
  y <- tibble(a = c("1", "x", "3"))

  expect_error(compare_data(x, y), "type")
})

test_that("compare_data errors clearly with no columns in common", {
  expect_error(compare_data(tibble(a = 1:2), tibble(b = 1:2)), "common")
})

test_that("compare_data accepts bare column names for context_cols", {
  x <- tibble(id = 1:3, a = c(1, 5, 3))
  y <- tibble(id = 1:3, a = c(1, 2, 3))

  result <- compare_data(x, y, context_rows = c(0L, 0L), context_cols = id)

  expect_named(
    result,
    c(".row", ".join_type", ".diff_type", ".source", "id", "a")
  )

  result_helper <- compare_data(
    x,
    y,
    context_rows = c(0L, 0L),
    context_cols = starts_with("i")
  )
  expect_true("id" %in% names(result_helper))
})

test_that("compare_data limits output with max_differences", {
  x <- tibble(a = 1:4)
  y <- tibble(a = c(9L, 2L, 8L, 7L))

  expect_message(
    result <- compare_data(x, y, context_rows = c(0L, 0L), max_differences = 2),
    "3 differing rows"
  )
  expect_equal(unique(result$.row), c(1, 3))
})

test_that("compare_groups rejects grouping columns named in_x or in_y", {
  x <- tibble(in_x = 1:2)
  y <- tibble(in_x = 2:3)

  expect_error(compare_groups(x, y, in_x), "in_x")
})

test_that("compare_columns returns a stable column order", {
  x <- tibble(a = 1)
  y <- tibble(a = 1, b = 2)

  # only "in y only" differences
  expect_named(compare_columns(x, y), c(".diff", "column", "x_type", "y_type"))

  # only "in x only" differences
  expect_named(compare_columns(y, x), c(".diff", "column", "x_type", "y_type"))

  # no differences: empty but with the same schema
  expect_named(compare_columns(x, x), c(".diff", "column", "x_type", "y_type"))
  expect_equal(nrow(compare_columns(x, x)), 0L)
})

test_that("truncation does not disguise hidden differences as context", {
  x <- tibble(a = 1:6)
  y <- tibble(a = rep(9L, 6))

  expect_message(
    result <- compare_data(
      x,
      y,
      context_rows = c(0L, 2L),
      max_differences = 1
    )
  )

  # rows 2-6 differ but are truncated away; they must not reappear as
  # context rows showing only x values
  expect_equal(unique(result$.row), 1)
})

test_that("compare_data matches rows by key columns", {
  x <- tibble(id = c(1, 2, 3), v = c("a", "b", "c"))
  y <- tibble(id = c(2, 3, 4), v = c("b", "XX", "d"))

  result <- compare_data(x, y, by = "id", context_rows = c(0L, 0L))

  # id 1 only in x, id 4 only in y, id 3 differs, id 2 matches
  expect_setequal(result$id, c(1, 3, 4))
  expect_equal(result$.join_type[result$id == 1], "x")
  expect_equal(result$.join_type[result$id == 4], "y")
  expect_setequal(result$v[result$id == 3], c("c", "XX"))
})

test_that("key matching is not misaligned by an inserted row", {
  x <- tibble(id = c(1, 2, 3), v = c("a", "b", "c"))
  y <- tibble(id = c(1, 1.5, 2, 3), v = c("a", "z", "b", "c"))

  result <- compare_data(x, y, by = "id", context_rows = c(0L, 0L))

  # only the inserted row differs
  expect_equal(result$id, 1.5)
  expect_equal(result$.join_type, "y")
})

test_that("compare_data supports multiple key columns", {
  x <- tibble(g = c("a", "a", "b"), i = c(1, 2, 1), v = 1:3)
  y <- tibble(g = c("a", "a", "b"), i = c(1, 2, 1), v = c(1L, 9L, 3L))

  result <- compare_data(x, y, by = c("g", "i"), context_rows = c(0L, 0L))

  expect_equal(unique(result$g), "a")
  expect_equal(unique(result$i), 2)
})

test_that("compare_data validates key columns", {
  x <- tibble(id = c(1, 1), v = 1:2)
  y <- tibble(id = c(1, 2), v = 1:2)

  expect_error(compare_data(x, y, by = "id"), "unique")
  expect_error(compare_data(y, x, by = "id"), "unique")
  expect_error(compare_data(y, y, by = "nope"), "subset")
  expect_error(compare_data(y, y, by = 1), "character")
})

test_that("compare_data works when only key columns are shared", {
  x <- tibble(id = 1:2)
  y <- tibble(id = 2:3)

  result <- compare_data(x, y, by = "id", context_rows = c(0L, 0L))

  expect_setequal(result$id, c(1, 3))
  expect_setequal(result$.join_type, c("x", "y"))
})
