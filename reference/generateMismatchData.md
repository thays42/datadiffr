# Extract the mismatching rows of a comparison

Given a comparison from
[`rCompare()`](https://thays42.github.io/datadiffr/reference/rCompare.md)
and the two original data frames, returns the rows of each frame that
mismatch, as in dataCompareR's `generateMismatchData()`. Keyed
comparisons return rows whose keys appear in any mismatch table, with
cleaned upper-case column names; keyless comparisons return the rows at
the mismatching positions with the original column names.

## Usage

``` r
generateMismatchData(x, dfA, dfB, ...)
```

## Arguments

- x:

  A comparison object returned by
  [`rCompare()`](https://thays42.github.io/datadiffr/reference/rCompare.md).

- dfA, dfB:

  The data frames that were compared. They are matched to the comparison
  by the names they were originally passed under.

- ...:

  Ignored, for compatibility.

## Value

A list of two data frames named `<name>_mm` after the original inputs.

## Examples

``` r
a <- data.frame(id = 1:3, value = c(1, 2, 3))
b <- data.frame(id = 1:3, value = c(1, 2.5, 3))
cmp <- rCompare(a, b, keys = "id")
generateMismatchData(cmp, a, b)
#> $a_mm
#>   ID VALUE
#> 2  2     2
#> 
#> $b_mm
#>   ID VALUE
#> 2  2   2.5
#> 
```
