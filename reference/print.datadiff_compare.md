# Print a dataCompareR-compatible comparison

Prints the one-line comparison status followed by head/tail excerpts of
each mismatching column's rows, in the dataCompareR console format.

## Usage

``` r
# S3 method for class 'datadiff_compare'
print(x, nVars = 5, nObs = 5, verbose = FALSE, ...)
```

## Arguments

- x:

  A comparison object returned by
  [`rCompare()`](https://thays42.github.io/datadiffr/reference/rCompare.md).

- nVars:

  Number of mismatched variables to show from the start and end of the
  variable list.

- nObs:

  Number of observations to show from the start and end of each
  variable's mismatch table.

- verbose:

  If `TRUE`, print every mismatching row of every variable.

- ...:

  Ignored, for method compatibility.

## Value

`x`, invisibly.
