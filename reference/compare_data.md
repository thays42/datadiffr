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

A `datadiff_result` object. `$kind` is `"identical"`, `"schema"`, or
`"value"`. For `"schema"` (the frames have different column names or
types) `$columns` holds a
[`compare_columns()`](https://thays42.github.io/datadiffr/reference/compare_columns.md)
tibble and `$rows` is `NULL`. For `"value"`/`"identical"` `$rows` holds
a `datadiff_diff` of the differences (empty when identical) and
`$columns` is `NULL`.

## Details

Rows are matched by position (row number), or by key columns when `by`
is given. `x` and `y` must share at least one column, and shared columns
must have compatible types; otherwise a `"schema"` result is returned
instead of a row-level comparison. Rows present in only one data frame
are always reported as differences.

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
#> ✔ No differences found.
```
