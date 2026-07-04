# Compare column metadata between two data frames

Compare column metadata between two data frames

## Usage

``` r
compare_columns(x, y)
```

## Arguments

- x, y:

  Data frames to compare.

## Value

A data frame with the following columns:

- `.diff` - The type of difference: `"in x only"`, `"in y only"`, or
  `"type conflict"`

- `column` - The column name

- `x_type` - The column type in `x` (if applicable)

- `y_type` - The column type in `y` (if applicable)

Returns an empty data frame if there are no differences.

## Examples

``` r
x <- data.frame(id = 1:3, value = 1:3, extra = letters[1:3])
y <- data.frame(id = 1:3, value = c(1.5, 2.5, 3.5))

# `value` differs in type (integer vs double) and `extra` is only in x
compare_columns(x, y)
#> # A tibble: 2 × 4
#>   .diff         column x_type    y_type 
#>   <chr>         <chr>  <chr>     <chr>  
#> 1 in x only     extra  character NA     
#> 2 type conflict value  integer   numeric
```
