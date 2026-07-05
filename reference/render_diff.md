# Render a diff in a flexdashboard

Opens the diff as an HTML report in the RStudio viewer (if available) or
browser. Optionally saves to a file.

## Usage

``` r
render_diff(diff, output_file = NULL)

# S3 method for class 'datadiff_compare'
render_diff(diff, output_file = NULL)

# S3 method for class 'datadiff_result'
render_diff(diff, output_file = NULL)

# Default S3 method
render_diff(diff, output_file = NULL)
```

## Arguments

- diff:

  A `datadiff_result` (from
  [`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md)),
  a `datadiff_compare` (from
  [`rCompare()`](https://thays42.github.io/datadiffr/reference/rCompare.md)),
  or a bare diff data frame containing `.row`, `.join_type`,
  `.diff_type`, and `.source` columns.

- output_file:

  Optional file path to save the HTML report. If provided, the report is
  saved to this location instead of (or in addition to) opening in the
  viewer.

## Value

Invisibly returns the path to the HTML file (either `output_file` if
provided, or a temporary file path).

## Examples

``` r
if (FALSE) { # interactive()
x <- data.frame(id = 1:5, score = c(10, 20, 30, 40, 50))
y <- data.frame(id = 1:5, score = c(10, 25, 30, 40, 55))

diff <- compare_data(x, y)
render_diff(diff)
}
```
