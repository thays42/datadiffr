# Diff Data Frames

High-level function that compares two data frames and renders the result
as an HTML report in the RStudio viewer or browser.

## Usage

``` r
diffdata(
  x,
  y,
  by = NULL,
  context_rows = c(3L, 3L),
  context_cols = everything(),
  max_differences = 10,
  tolerance = .Machine$double.eps^0.5,
  output_file = NULL
)
```

## Arguments

- x, y:

  Data frames to diff.

- by:

  Optional character vector of key columns to match rows on, like a
  join. When `NULL` (the default), rows are matched by position. See
  [`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md)
  for details.

- context_rows:

  Integer vector of length two indicating the number of context rows to
  include before and after a difference row.

- context_cols:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Columns to include as context.

- max_differences:

  Maximum number of differing rows to report. Defaults to 10 (unlike
  [`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md),
  which reports everything) to keep reports fast to render.

- tolerance:

  Numeric tolerance for comparing numeric values.

- output_file:

  Optional file path to save the HTML report. If provided, the report is
  saved to this location instead of opening in the viewer.

## Value

Invisibly, a `datadiff_result` object (see
[`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md)).
Called for its side effect: when columns match and values differ it
renders an HTML report; when columns differ it prints the schema
differences to the console; when the frames are identical it reports no
differences.

## Examples

``` r
if (FALSE) { # interactive()
x <- data.frame(id = 1:5, score = c(10, 20, 30, 40, 50))
y <- data.frame(id = 1:5, score = c(10, 25, 30, 40, 55))

# Opens a styled HTML diff report in the RStudio viewer or browser
diffdata(x, y)

# Or write the report to a file instead of opening it
diffdata(x, y, output_file = tempfile(fileext = ".html"))
}
```
