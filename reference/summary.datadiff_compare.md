# Summarize a dataCompareR-compatible comparison

Builds the same summary object as dataCompareR's
`summary.dataCompareRobject()`: a list of run metadata, column and row
matching counts, and per-column mismatch details, printable as a
markdown report.

## Usage

``` r
# S3 method for class 'datadiff_compare'
summary(object, mismatchCount = 5, ...)

# S3 method for class 'summary.datadiff_compare'
print(x, ...)
```

## Arguments

- object:

  A comparison object returned by
  [`rCompare()`](https://thays42.github.io/datadiffr/reference/rCompare.md).

- mismatchCount:

  Maximum number of rows to keep in each per-column detail table.

- ...:

  Ignored, for method compatibility.

- x:

  A summary object returned by `summary.datadiff_compare()`.

## Value

A list of class
`c("summary.datadiff_compare", "summary.dataCompareRobject")` with the
dataCompareR summary fields.

## Details

Unlike dataCompareR (which samples), detail tables are deterministic:
rows are sorted by decreasing absolute difference and the first
`mismatchCount` are kept.

## Examples

``` r
a <- data.frame(id = 1:3, value = c(1, 2, 3))
b <- data.frame(id = 1:3, value = c(1, 2.5, 3))
summary(rCompare(a, b, keys = "id"))
#> 
#> Data Comparison
#> ===============
#> 
#> Date comparison run: 2026-07-04 20:28:18  
#> Comparison run on R version 4.6.1 (2026-06-24)  
#> With datadiffr version 0.1.0  
#> 
#> Meta Summary
#> ============
#> 
#> |Dataset Name |Number of Rows |Number of Columns |
#> |:------------|:--------------|:-----------------|
#> |a            |3              |2                 |
#> |b            |3              |2                 |
#> 
#> Variable Summary
#> ================
#> 
#> Number of columns in common: 2  
#> Number of columns only in a: 0  
#> Number of columns only in b: 0  
#> Number of columns with a type mismatch: 0  
#> Match keys : 1   - ID
#> 
#> 
#> Row Summary
#> ===========
#> 
#> Total number of rows read from a: 3  
#> Total number of rows read from b: 3  
#> Number of rows in common: 3  
#> Number of rows dropped from a: 0  
#> Number of rows dropped from b: 0  
#> 
#> 
#> Data Values Comparison Summary
#> ==============================
#> 
#> Number of columns compared with ALL rows equal: 0  
#> Number of columns compared with SOME rows unequal: 1  
#> Number of columns with missing value differences: 0  
#> 
#> Summary of columns with some rows unequal: 
#> 
#> |Column |Type (in a) |Type (in b) | # differences|Max difference | # NAs|
#> |:------|:-----------|:-----------|-------------:|:--------------|-----:|
#> |VALUE  |double      |double      |             1|0.5            |     0|
#> 
#> 
#> Unequal column details
#> ======================
#> 
#> #### Column -  VALUE
#> 
#> | ID| VALUE (a)| VALUE (b)|Type (a) |Type (b) | Difference|
#> |--:|---------:|---------:|:--------|:--------|----------:|
#> |  2|         2|       2.5|double   |double   |       -0.5|
#> 
```
