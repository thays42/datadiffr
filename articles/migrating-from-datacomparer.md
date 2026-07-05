# Migrating from dataCompareR

dataCompareR was archived by CRAN in February 2026 and its repository is
read-only. If
[`rCompare()`](https://thays42.github.io/datadiffr/reference/rCompare.md)
is part of your workflow, datadiffr provides a drop-in replacement for
the package’s entire exported surface —
[`rCompare()`](https://thays42.github.io/datadiffr/reference/rCompare.md),
[`print()`](https://rdrr.io/r/base/print.html),
[`summary()`](https://rdrr.io/r/base/summary.html),
[`saveReport()`](https://thays42.github.io/datadiffr/reference/saveReport.md),
and
[`generateMismatchData()`](https://thays42.github.io/datadiffr/reference/generateMismatchData.md)
— reimplemented from scratch (no dataCompareR code is reused) and
verified field-by-field against dataCompareR itself in datadiffr’s test
suite.

In most scripts, migration means replacing
[`library(dataCompareR)`](https://github.com/capitalone/dataCompareR)
with:

``` r

library(datadiffr)
```

## Quick start

``` r

library(datadiffr)

orders_old <- data.frame(
  order_id = 1:5,
  amount = c(10, 20.5, 30, 45, 50),
  status = c("open", "open", "closed", "open", "closed")
)
orders_new <- data.frame(
  order_id = c(1:4, 6L),
  amount = c(10, 21.0, 30, 45, 60),
  status = c("open", "paid", "closed", "open", "open")
)

cmp <- rCompare(orders_old, orders_new, keys = "order_id")
cmp
#> All columns were compared, 2 row(s) were dropped from comparison
#> There are 2 mismatched variables:
#> First and last 5 observations for the 2 mismatched variables
#>   ORDER_ID valueA valueB variable     typeA     typeB diffAB
#> 1        2   20.5     21   AMOUNT    double    double   -0.5
#> 2        2   open   paid   STATUS character character
```

The full report, as before:

``` r

summary(cmp)
#> 
#> Data Comparison
#> ===============
#> 
#> Date comparison run: 2026-07-05 20:37:10  
#> Comparison run on R version 4.6.1 (2026-06-24)  
#> With datadiffr version 0.1.0  
#> 
#> Meta Summary
#> ============
#> 
#> |Dataset Name |Number of Rows |Number of Columns |
#> |:------------|:--------------|:-----------------|
#> |orders_old   |5              |3                 |
#> |orders_new   |5              |3                 |
#> 
#> Variable Summary
#> ================
#> 
#> Number of columns in common: 3  
#> Number of columns only in orders_old: 0  
#> Number of columns only in orders_new: 0  
#> Number of columns with a type mismatch: 0  
#> Match keys : 1   - ORDER_ID
#> 
#> 
#> Row Summary
#> ===========
#> 
#> Total number of rows read from orders_old: 5  
#> Total number of rows read from orders_new: 5  
#> Number of rows in common: 4  
#> Number of rows dropped from orders_old: 1  
#> Number of rows dropped from orders_new: 1  
#> 
#> 
#> Data Values Comparison Summary
#> ==============================
#> 
#> Number of columns compared with ALL rows equal: 0  
#> Number of columns compared with SOME rows unequal: 2  
#> Number of columns with missing value differences: 0  
#> 
#> Summary of columns with some rows unequal: 
#> 
#> |Column |Type (in orders_old) |Type (in orders_new) | # differences|Max difference | # NAs|
#> |:------|:--------------------|:--------------------|-------------:|:--------------|-----:|
#> |AMOUNT |double               |double               |             1|0.5            |     0|
#> |STATUS |character            |character            |             1|NA             |     0|
#> 
#> 
#> Unequal column details
#> ======================
#> 
#> #### Column -  AMOUNT
#> 
#> | ORDER_ID| AMOUNT (orders_old)| AMOUNT (orders_new)|Type (orders_old) |Type (orders_new) | Difference|
#> |--------:|-------------------:|-------------------:|:-----------------|:-----------------|----------:|
#> |        2|                20.5|                  21|double            |double            |       -0.5|
#> 
#> #### Column -  STATUS
#> 
#> | ORDER_ID|STATUS (orders_old) |STATUS (orders_new) |Type (orders_old) |Type (orders_new) |Difference |
#> |--------:|:-------------------|:-------------------|:-----------------|:-----------------|:----------|
#> |        2|open                |paid                |character         |character         |           |
#> 
#> Dropped Rows Details
#> ====================
#> 
#> The following rows were dropped from orders_old
#> 
#> | ORDER_ID|
#> |--------:|
#> |        5|
#> 
#> The following rows were dropped from orders_new
#> 
#> | ORDER_ID|
#> |--------:|
#> |        6|
```

Everything downstream works the same way:

``` r

mismatches <- generateMismatchData(cmp, orders_old, orders_new)
mismatches$orders_old_mm
#>   ORDER_ID AMOUNT STATUS
#> 2        2   20.5   open
```

``` r

saveReport(cmp, reportName = "orders", reportLocation = ".")
```

## The compatibility surface

| dataCompareR | datadiffr | Notes |
|----|----|----|
| `rCompare(dfA, dfB, keys, roundDigits, mismatches, trimChars)` | Same | Plus a `tolerance` extension (see below) |
| `print(x, nVars, nObs, verbose)` | Same | Same console format |
| `summary(x, mismatchCount)` | Same | Same fields; deterministic detail tables |
| `saveReport(...)` | Same | Same arguments, rendered with rmarkdown |
| `generateMismatchData(x, dfA, dfB)` | Same | Same validation and return shape |

The returned object has class
`c("datadiff_compare", "dataCompareRobject")` and the same six fields
(`meta`, `colMatching`, `rowMatching`, `cleaninginfo`, `mismatches`,
`matches`) with the same shapes, so code that inspects the object —
`cmp$mismatches$AMOUNT`, `cmp$rowMatching$inboth`, and so on — keeps
working.

The comparison semantics are preserved, including the corners:

- Column names are cleaned with
  [`make.names()`](https://rdrr.io/r/base/make.names.html) and matched
  case-insensitively; shared columns are reported upper-case and sorted.
- Without `keys`, rows are compared by position and the longer frame is
  truncated (recorded in `rowMatching$inA$indices_removed`).
- With `keys`, key columns must exist in both frames (checked
  case-sensitively against the cleaned names) and must identify rows
  uniquely in each frame.
- `NA` matches `NA` and `NaN` matches `NaN`, but `NA` does not match
  `NaN`.
- Factors are compared as character, and the coercion is recorded in
  `cleaninginfo`.
- Columns whose classes differ between the frames (for example integer
  vs double) are reported as mismatching on every row, with types shown
  and a blank difference.
- The `mismatches` cap **errors** when exceeded — it does not truncate —
  exactly as dataCompareR behaved.

## Known differences

These are deliberate and documented; none change the object contract:

- **Detail tables are deterministic.** Where dataCompareR *sampled* rows
  for [`summary()`](https://rdrr.io/r/base/summary.html) detail tables
  beyond `mismatchCount`, datadiffr sorts by decreasing absolute
  difference and keeps the first rows. Reruns produce identical reports.
- **Metadata references datadiffr.** `summary()$version` is the
  datadiffr version, and report headers say “With datadiffr version …”.
- **Clear validation errors.** Inputs must be data frames (dataCompareR
  silently coerced some malformed inputs into empty comparisons), and
  error messages are worded differently, though they fire in the same
  situations.

## Extensions

[`rCompare()`](https://thays42.github.io/datadiffr/reference/rCompare.md)
gains a `tolerance` argument, appended after the original arguments so
positional calls behave identically. dataCompareR’s only fuzziness
mechanism was `roundDigits` (round both sides, then compare exactly),
which fails on values that round in different directions:

``` r

a <- data.frame(x = 1.14)
b <- data.frame(x = 1.16)
# rounds to 1.1 vs 1.2: reported as a mismatch
length(rCompare(a, b, roundDigits = 1)$mismatches)
#> [1] 1
# absolute tolerance: equal
length(rCompare(a, b, tolerance = 0.05)$mismatches)
#> [1] 0
```

The default `tolerance = 0` keeps faithful exact comparison.

The second extension is
[`render_diff()`](https://thays42.github.io/datadiffr/reference/render_diff.md):
datadiffr’s styled HTML diff report, straight from the comparison
object.

``` r

render_diff(cmp)                          # opens in the viewer
render_diff(cmp, output_file = "cmp.html") # or saves to a file
```

## Graduating to the native API

The compatibility layer is a stable endpoint — you can stay on it. But
datadiffr’s native API adds things
[`rCompare()`](https://thays42.github.io/datadiffr/reference/rCompare.md)
cannot express:

``` r

diffdata(
  orders_old,
  orders_new,
  by = "order_id",        # key-based matching, like rCompare keys
  context_rows = c(2, 2), # unified-diff style context around changes
  context_cols = c(order_id, amount),
  tolerance = 0.01
)
```

[`diffdata()`](https://thays42.github.io/datadiffr/reference/diffdata.md)
compares, then opens the HTML diff report with added rows in green,
removed rows in red, and unchanged context rows for orientation.
[`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md)
returns the underlying diff as a `datadiff_result` (with the diff rows
in `$rows`) for programmatic use.

## Troubleshooting

- **“Key … was not found in both data frames”** — key names are checked
  against the
  [`make.names()`](https://rdrr.io/r/base/make.names.html)-cleaned
  column names, case-sensitively: `keys = "ID"` does not find a column
  named `id`. This matches dataCompareR.
- **“Detected N mismatches, which exceeds the `mismatches` cap”** — the
  cap is a guard, not a limit; raise it or drop the argument, as with
  dataCompareR.
- **[`generateMismatchData()`](https://thays42.github.io/datadiffr/reference/generateMismatchData.md)
  says a frame was not part of the original comparison** — like
  dataCompareR, frames are matched by the *names* they were passed under
  at
  [`rCompare()`](https://thays42.github.io/datadiffr/reference/rCompare.md)
  time; pass the same variables.
- **[`render_diff()`](https://thays42.github.io/datadiffr/reference/render_diff.md)
  asks for flexdashboard** — the HTML diff report needs the suggested
  flexdashboard package: `install.packages("flexdashboard")`.
