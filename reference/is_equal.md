# Vectorized Equality Test

Element-wise equality comparison that handles `NA` and `Inf` values
correctly, and supports numeric tolerance for floating-point
comparisons.

## Usage

``` r
is_equal(x, y, tolerance = .Machine$double.eps^0.5)
```

## Arguments

- x, y:

  Vectors to compare. Must be the same length, or either can be length
  1.

- tolerance:

  Numeric tolerance for comparison. Only applies to numeric values.

## Value

A logical vector the same length as `x` and `y`, where each element is
`TRUE` if the corresponding elements are equal (within tolerance for
numeric values) and `FALSE` otherwise.

## Details

Comparison semantics:

- `NA` values are equal to each other, and `NaN` values are equal to
  each other, but `NA` is not equal to `NaN`.

- Factors are compared by their character values, so factors with
  different level sets can be compared.

- Dates and datetimes are compared numerically, so `tolerance` applies
  on the underlying scale (days for `Date`, seconds for `POSIXct`).

- Lists are compared element-wise with
  [`identical()`](https://rdrr.io/r/base/identical.html); `tolerance`
  does not apply.

- When `x` and `y` have incompatible types (e.g. numeric vs character),
  every element is `FALSE`.

## Examples

``` r
is_equal(c(1, 2, NA), c(1, 5, NA))
#> [1]  TRUE FALSE  TRUE

# NA equals NA and NaN equals NaN, but NA does not equal NaN
is_equal(NA, NaN)
#> [1] FALSE

# Tolerance controls how close numeric values must be
is_equal(1, 1.001)
#> [1] FALSE
is_equal(1, 1.001, tolerance = 0.01)
#> [1] TRUE
```
