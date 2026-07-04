# Compare two data frames, dataCompareR style

A drop-in replacement for `rCompare()` from the archived 'dataCompareR'
package. Compares two data frames — by row position, or by key columns
when `keys` is supplied — and returns a summary object with the same
shape as a `dataCompareRobject`, so existing code and scripts written
against 'dataCompareR' keep working.

## Usage

``` r
rCompare(
  dfA,
  dfB,
  keys = NA,
  roundDigits = NA,
  mismatches = NA,
  trimChars = FALSE,
  tolerance = 0
)
```

## Arguments

- dfA, dfB:

  Data frames to compare.

- keys:

  Character vector of key columns used to match rows, or `NA` (the
  default) to match rows by position. Keys must identify rows uniquely
  in each frame.

- roundDigits:

  If not `NA`, round double columns to this many digits before
  comparing.

- mismatches:

  If not `NA`, the maximum total number of mismatching values allowed;
  an error is thrown when the comparison finds more.

- trimChars:

  If `TRUE`, trim leading and trailing whitespace from character columns
  before comparing.

- tolerance:

  Numeric tolerance for comparing numeric values, as in
  [`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md).
  Defaults to `0` (exact comparison, as dataCompareR behaves).

## Value

An object of class `c("datadiff_compare", "dataCompareRobject")`: a list
with elements `meta`, `colMatching`, `rowMatching`, `cleaninginfo`,
`mismatches`, and `matches`, mirroring dataCompareR's return value.

## Details

Following the dataCompareR contract: column names are cleaned with
[`make.names()`](https://rdrr.io/r/base/make.names.html) and matched
case-insensitively (shared columns are reported in upper case, sorted
alphabetically); factors are compared as character and the coercion is
recorded in `cleaninginfo`; `NA` matches `NA` and `NaN` matches `NaN`,
but `NA` does not match `NaN`; columns whose classes differ between the
two frames are reported as mismatching on every row. Without `keys`, the
longer frame is truncated to the length of the shorter and rows are
compared by position.

`tolerance` is a datadiffr extension (dataCompareR only offers
`roundDigits`). The default `0` keeps faithful exact comparison.

## Examples

``` r
a <- data.frame(id = 1:3, value = c(1, 2, 3))
b <- data.frame(id = 1:3, value = c(1, 2.5, 3))
rCompare(a, b, keys = "id")
#> All columns were compared, all rows were compared
#> There are 1 mismatched variables:
#> First and last 5 observations for the 1 mismatched variables
#>   ID valueA valueB variable  typeA  typeB diffAB
#> 1  2      2    2.5    VALUE double double   -0.5
```
