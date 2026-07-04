# Compare two data frames

Compare two data frames

## Usage

``` r
compare_data(
  x,
  y,
  by = NULL,
  context_rows = c(3L, 3L),
  context_cols = everything(),
  max_differences = Inf,
  tolerance = .Machine$double.eps^0.5
)
```

## Arguments

- x, y:

  Data frames to compare.

- by:

  Optional character vector of key columns to match rows on, like a
  join. Key columns must exist in both data frames and uniquely identify
  rows in each. When `NULL` (the default), rows are matched by position
  (row number). With `by`, the output is ordered by the key columns and
  key columns are always included in the output.

- context_rows:

  Integer vector of length two indicating the number of context rows to
  include before and after a difference row.

- context_cols:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Columns to include as context.

- max_differences:

  Maximum number of differing rows to report. When exceeded, only the
  first `max_differences` differing rows are returned (with a message).

- tolerance:

  Numeric tolerance for comparing numeric values.

## Value

A data frame containing differences between `x` and `y` with the
following columns:

- `.row` - The row number from the original data frames

- `.join_type` - Whether the row is in `"x"`, `"y"`, or `"both"`

- `.diff_type` - Whether the row is a `"diff"` or `"context"` row

- `.source` - For diff rows, whether this is the `"x"` or `"y"` version;
  `NA` for context rows

Plus the original data columns (context columns and columns with
differences).

## Details

Rows are matched by position (row number), or by key columns when `by`
is given. `x` and `y` must share at least one column, and shared columns
must have compatible types; otherwise an error is thrown. Rows present
in only one data frame are always reported as differences.

## Examples

``` r
x <- data.frame(id = 1:4, score = c(10, 20, 30, 40))
y <- data.frame(id = 1:4, score = c(10, 25, 30, 45))

# Rows are matched by position by default
compare_data(x, y, context_rows = c(1L, 1L))
#> datadiff: 2 changed, 0 added, 0 removed rows across 1 column
#> Tolerance: 1.49011611938477e-08
#> 
#> # A tibble: 6 × 6
#>    .row .join_type .diff_type .source    id score
#>   <int> <chr>      <chr>      <chr>   <int> <dbl>
#> 1     1 both       context    NA          1    10
#> 2     2 both       diff       x           2    20
#> 3     2 both       diff       y           2    25
#> 4     3 both       context    NA          3    30
#> 5     4 both       diff       x           4    40
#> 6     4 both       diff       y           4    45

# Match on a key column instead of position
compare_data(x, y, by = "id")
#> datadiff: 2 changed, 0 added, 0 removed rows across 1 column
#> Tolerance: 1.49011611938477e-08
#> 
#> # A tibble: 6 × 6
#>    .row .join_type .diff_type .source    id score
#>   <int> <chr>      <chr>      <chr>   <int> <dbl>
#> 1     1 both       context    NA          1    10
#> 2     2 both       diff       x           2    20
#> 3     2 both       diff       y           2    25
#> 4     3 both       context    NA          3    30
#> 5     4 both       diff       x           4    40
#> 6     4 both       diff       y           4    45

# A numeric tolerance treats near-equal values as equal
compare_data(x, y, tolerance = 10)
#> datadiff: 0 changed, 0 added, 0 removed rows across 0 columns
#> Tolerance: 10
#> 
#> # A tibble: 0 × 6
#> # ℹ 6 variables: .row <int>, .join_type <chr>, .diff_type <chr>, .source <chr>,
#> #   id <int>, score <dbl>
```
