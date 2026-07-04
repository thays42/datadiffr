# Save a comparison report

Writes the
[`summary.datadiff_compare()`](https://thays42.github.io/datadiffr/reference/summary.datadiff_compare.md)
report of a comparison to disk as R Markdown and (optionally) rendered
HTML, as in dataCompareR's `saveReport()`.

## Usage

``` r
saveReport(
  compareObject,
  reportName,
  reportLocation = ".",
  HTMLReport = TRUE,
  showInViewer = TRUE,
  stylesheet = NA,
  printAll = FALSE,
  ...
)
```

## Arguments

- compareObject:

  A comparison object returned by
  [`rCompare()`](https://thays42.github.io/datadiffr/reference/rCompare.md).

- reportName:

  File name for the report, without extension.

- reportLocation:

  Existing directory to write the report to.

- HTMLReport:

  If `TRUE`, render the report to HTML (requires pandoc); the
  intermediate markdown is kept alongside it.

- showInViewer:

  If `TRUE` and the session is interactive, open the rendered HTML
  report in the RStudio viewer or browser.

- stylesheet:

  Optional path to a CSS file for the HTML report, or `NA` for the
  default style.

- printAll:

  If `TRUE`, the per-column detail tables include every mismatching row
  instead of the first five.

- ...:

  Ignored, for compatibility.

## Value

`NULL`, invisibly.

## Examples

``` r
a <- data.frame(id = 1:3, value = c(1, 2, 3))
b <- data.frame(id = 1:3, value = c(1, 2.5, 3))
cmp <- rCompare(a, b, keys = "id")
saveReport(
  cmp,
  reportName = "example",
  reportLocation = tempdir(),
  showInViewer = FALSE
)
```
