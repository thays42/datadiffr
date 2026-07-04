# Compare groups between two data frames

Compare groups between two data frames

## Usage

``` r
compare_groups(x, y, group_cols)
```

## Arguments

- x, y:

  Data frames to compare

- group_cols:

  \<[`tidy-select`](https://dplyr.tidyverse.org/reference/dplyr_tidy_select.html)\>
  Columns to use for grouping

## Value

A data frame containing the grouping columns and two additional columns,
`in_x` and `in_y`, which are TRUE if the group values are in the
corresponding data frame and FALSE otherwise. Records where both `in_x`
and `in_y` are TRUE are excluded from the output.

## Examples

``` r
x <- data.frame(team = c("a", "a", "b"), player = 1:3)
y <- data.frame(team = c("a", "b", "c"), player = 4:6)

# Team values that appear in only one of the frames
compare_groups(x, y, group_cols = team)
#>   team  in_x in_y
#> 1    c FALSE TRUE
```
