# Get started with datadiffr

``` r

library(datadiffr)
```

datadiffr compares two data frames and reports the differences the way a
code review shows a diff: cell by cell, with a few unchanged rows around
each change for context. This vignette walks through the core workflow —
comparing frames, controlling context, matching rows by key, tolerating
small numeric differences, and rendering an HTML report.

## A first comparison

Start with two versions of the same small table.
[`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md)
returns the differences as a tidy data frame.

``` r

before <- data.frame(
  id    = 1:6,
  name  = c("Ana", "Ben", "Cai", "Dana", "Eve", "Finn"),
  score = c(88, 91, 75, 82, 95, 60)
)
after <- data.frame(
  id    = 1:6,
  name  = c("Ana", "Ben", "Cai", "Dana", "Eve", "Finn"),
  score = c(88, 91, 79, 82, 95, 72)
)

compare_data(before, after)
#> datadiff: 2 changed, 0 added, 0 removed rows across 1 column
#> Tolerance: 1.49011611938477e-08
#> 
#> # A tibble: 8 × 7
#>    .row .join_type .diff_type .source    id name  score
#>   <int> <chr>      <chr>      <chr>   <int> <chr> <dbl>
#> 1     1 both       context    NA          1 Ana      88
#> 2     2 both       context    NA          2 Ben      91
#> 3     3 both       diff       x           3 Cai      75
#> 4     3 both       diff       y           3 Cai      79
#> 5     4 both       context    NA          4 Dana     82
#> 6     5 both       context    NA          5 Eve      95
#> 7     6 both       diff       x           6 Finn     60
#> 8     6 both       diff       y           6 Finn     72
```

The result carries a few bookkeeping columns alongside your data:

- `.row` — the row number the difference came from.
- `.join_type` — whether the row is in `"x"`, `"y"`, or `"both"`.
- `.diff_type` — whether the row is a `"diff"` or a `"context"` row.
- `.source` — for diff rows, whether it is the `"x"` (before) or `"y"`
  (after) version; `NA` for context rows.

Each changed row appears twice — the before value above the after value
— so you can read the change top to bottom, like a unified diff. The
object prints a one-line summary above the table (here, two changed
rows), which is handy when you are working in a plain console rather
than the HTML report.

## Controlling context

By default datadiffr surrounds each change with three unchanged rows
before and after. `context_rows` takes a length-two vector — rows
before, rows after — so you can widen, narrow, or drop the context
entirely.

``` r

# No context: only the rows that actually changed
compare_data(before, after, context_rows = c(0L, 0L))
#> datadiff: 2 changed, 0 added, 0 removed rows across 1 column
#> Tolerance: 1.49011611938477e-08
#> 
#> # A tibble: 4 × 7
#>    .row .join_type .diff_type .source    id name  score
#>   <int> <chr>      <chr>      <chr>   <int> <chr> <dbl>
#> 1     3 both       diff       x           3 Cai      75
#> 2     3 both       diff       y           3 Cai      79
#> 3     6 both       diff       x           6 Finn     60
#> 4     6 both       diff       y           6 Finn     72
```

``` r

# One row of context on each side
compare_data(before, after, context_rows = c(1L, 1L))
#> datadiff: 2 changed, 0 added, 0 removed rows across 1 column
#> Tolerance: 1.49011611938477e-08
#> 
#> # A tibble: 7 × 7
#>    .row .join_type .diff_type .source    id name  score
#>   <int> <chr>      <chr>      <chr>   <int> <chr> <dbl>
#> 1     2 both       context    NA          2 Ben      91
#> 2     3 both       diff       x           3 Cai      75
#> 3     3 both       diff       y           3 Cai      79
#> 4     4 both       context    NA          4 Dana     82
#> 5     5 both       context    NA          5 Eve      95
#> 6     6 both       diff       x           6 Finn     60
#> 7     6 both       diff       y           6 Finn     72
```

You can also restrict which columns are shown as context with
`context_cols`, using tidyselect syntax (for example
`context_cols = c(id, name)`).

## Matching rows by key

The examples above match rows by position. When rows can move — a sort
changed, rows were inserted or deleted — match on one or more key
columns instead with `by =`. Keys must exist in both frames and identify
rows uniquely; the output is ordered by the key and always includes it.

``` r

# `after` is shuffled and has a new row (id 7) and a dropped row (id 3)
after_shuffled <- data.frame(
  id    = c(2L, 1L, 4L, 5L, 6L, 7L),
  name  = c("Ben", "Ana", "Dana", "Eve", "Finn", "Gwen"),
  score = c(91, 88, 82, 95, 72, 70)
)

compare_data(before, after_shuffled, by = "id", context_rows = c(0L, 0L))
#> datadiff: 1 changed, 1 added, 1 removed row across 2 columns
#> Tolerance: 1.49011611938477e-08
#> 
#> # A tibble: 4 × 7
#>    .row .join_type .diff_type .source    id name  score
#>   <int> <chr>      <chr>      <chr>   <int> <chr> <dbl>
#> 1     3 x          diff       x           3 Cai      75
#> 2     6 both       diff       x           6 Finn     60
#> 3     6 both       diff       y           6 Finn     72
#> 4     7 y          diff       y           7 Gwen     70
```

Rows present in only one frame are always reported: id 3 shows up as
removed (in `x` only) and id 7 as added (in `y` only).

## Tolerating small numeric differences

Floating-point data is rarely bit-identical. `tolerance` treats numeric
values within a threshold as equal, so tiny differences don’t flood the
report.

``` r

measured  <- data.frame(id = 1:3, value = c(1.0000, 2.0000, 3.0000))
recomputed <- data.frame(id = 1:3, value = c(1.0001, 2.5000, 3.0000))

# Exact-ish comparison flags both id 1 and id 2
compare_data(measured, recomputed, context_rows = c(0L, 0L))
#> datadiff: 2 changed, 0 added, 0 removed rows across 1 column
#> Tolerance: 1.49011611938477e-08
#> 
#> # A tibble: 4 × 6
#>    .row .join_type .diff_type .source    id value
#>   <int> <chr>      <chr>      <chr>   <int> <dbl>
#> 1     1 both       diff       x           1  1   
#> 2     1 both       diff       y           1  1.00
#> 3     2 both       diff       x           2  2   
#> 4     2 both       diff       y           2  2.5

# A tolerance of 0.01 keeps only the genuine change (id 2)
compare_data(measured, recomputed, tolerance = 0.01, context_rows = c(0L, 0L))
#> datadiff: 1 changed, 0 added, 0 removed rows across 1 column
#> Tolerance: 0.01
#> 
#> # A tibble: 2 × 6
#>    .row .join_type .diff_type .source    id value
#>   <int> <chr>      <chr>      <chr>   <int> <dbl>
#> 1     2 both       diff       x           2   2  
#> 2     2 both       diff       y           2   2.5
```

The same `tolerance` argument is available on
[`diffdata()`](https://thays42.github.io/datadiffr/reference/diffdata.md)
and
[`is_equal()`](https://thays42.github.io/datadiffr/reference/is_equal.md),
and it applies on the natural scale for dates (days) and datetimes
(seconds).

## When the columns themselves differ

datadiffr compares values, so it expects the two frames to share the
same columns with compatible types. If they don’t, it reports the
*column* differences instead of trying to diff the values. You can
inspect those directly with
[`compare_columns()`](https://thays42.github.io/datadiffr/reference/compare_columns.md).

``` r

x <- data.frame(id = 1:3, value = 1:3, note = c("a", "b", "c"))
y <- data.frame(id = 1:3, value = c(1.5, 2.5, 3.5))

compare_columns(x, y)
#> # A tibble: 2 × 4
#>   .diff         column x_type    y_type 
#>   <chr>         <chr>  <chr>     <chr>  
#> 1 in x only     note   character NA     
#> 2 type conflict value  integer   numeric
```

Here `value` changed type (integer to double) and `note` exists only in
`x`.

## Rendering an HTML report

[`diffdata()`](https://thays42.github.io/datadiffr/reference/diffdata.md)
runs the comparison and opens the result as a styled, self-contained
HTML report — changed rows colored red (before) and green (after), with
context rows grayed out. In an interactive session it opens in the
RStudio viewer or your browser:

``` r

diffdata(before, after)
```

To save the report instead of opening it, pass `output_file`:

``` r

diffdata(before, after, output_file = "diff-report.html")
```

[`diffdata()`](https://thays42.github.io/datadiffr/reference/diffdata.md)
defaults to `max_differences = 10` to keep reports fast to render; raise
it if you need every difference in the report.
[`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md),
which is meant for programmatic use, reports everything by default.

If you already have a diff from
[`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md),
render it directly with
[`render_diff()`](https://thays42.github.io/datadiffr/reference/render_diff.md):

``` r

diff <- compare_data(before, after)
render_diff(diff)
```

## Coming from dataCompareR?

datadiffr also ships a clean-room drop-in replacement for the archived
dataCompareR package —
[`rCompare()`](https://thays42.github.io/datadiffr/reference/rCompare.md)
and friends. See
[`vignette("migrating-from-datacomparer")`](https://thays42.github.io/datadiffr/articles/migrating-from-datacomparer.md).
