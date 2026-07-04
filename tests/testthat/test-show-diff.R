# show_diff() renders the HTML diff table. Blocks of contiguous rows are
# separated with a border rule rather than kableExtra's per-block group rows,
# which are O(n^2) in the number of blocks (53s at ~1.5k rows).

test_that("show_diff separates blocks with a border, not group rows", {
  # diffs at rows 2 and 9 are far apart -> two separate blocks
  x <- tibble(a = 1:10)
  y <- tibble(a = c(1L, 9L, 3L, 4L, 5L, 6L, 7L, 8L, 99L, 10L))

  diff <- compare_data(x, y, context_rows = c(0L, 0L))
  html <- as.character(show_diff(diff))

  # no kableExtra group-header rows (the O(n^2) pack_rows markup)
  expect_false(grepl("grouplength", html))
  # blocks are separated by a border rule
  expect_true(grepl("border-top", html))
})

test_that("show_diff colours added and removed rows", {
  x <- tibble(a = c(1L, 2L))
  y <- tibble(a = c(1L, 9L))

  diff <- compare_data(x, y, context_rows = c(0L, 0L))
  html <- as.character(show_diff(diff))

  # removed (x) cells are red, added (y) cells green
  expect_true(grepl("color:red", html))
  expect_true(grepl("color:green", html))
})

test_that("show_diff adds column separators without per-cell column_spec", {
  x <- tibble(a = c(1L, 2L), b = c(3L, 4L))
  y <- tibble(a = c(1L, 9L), b = c(3L, 4L))

  diff <- compare_data(x, y, context_rows = c(0L, 0L))
  html <- as.character(show_diff(diff))

  # column borders come from a single scoped stylesheet rule
  expect_true(grepl("lightable-paper td", html))
  expect_true(grepl("border-left: 1px solid #eeeeee", html))
})

test_that("show_diff renders a single block without a leading separator", {
  x <- tibble(a = c(1L, 2L, 3L))
  y <- tibble(a = c(1L, 9L, 3L))

  diff <- compare_data(x, y, context_rows = c(1L, 1L))
  html <- as.character(show_diff(diff))

  # one contiguous block -> no block-separator border
  expect_false(grepl("border-top", html))
})
