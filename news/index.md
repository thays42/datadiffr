# Changelog

## datadiffr 0.1.0

First release.

datadiffr compares two data frames and reports the differences cell by
cell, with configurable context rows around each change, as a styled
self-contained HTML report.

### Comparison

- [`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md)
  now returns a consolidated `datadiff_result` object with a `kind` of
  `"identical"`, `"schema"`, or `"value"`, instead of a bare diff
  tibble. Differing columns are reported as a `"schema"` result rather
  than an error, and
  [`diffdata()`](https://thays42.github.io/datadiffr/reference/diffdata.md)
  always returns this object invisibly
  ([\#12](https://github.com/thays42/datadiffr/issues/12)).
- [`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md)
  compares two data frames and returns the differences as a tidy data
  frame, matching rows by position or by key columns (`by =`), with
  configurable context rows around each change.
- [`diffdata()`](https://thays42.github.io/datadiffr/reference/diffdata.md)
  runs the comparison and renders it as an HTML report in the RStudio
  viewer, browser, or a file.
- [`compare_columns()`](https://thays42.github.io/datadiffr/reference/compare_columns.md)
  reports column name and type differences, and
  [`compare_groups()`](https://thays42.github.io/datadiffr/reference/compare_groups.md)
  compares group membership between two frames.
- [`is_equal()`](https://thays42.github.io/datadiffr/reference/is_equal.md)
  provides tolerance-aware, vectorized equality that handles `NA`,
  `NaN`, and infinite values, and compares factors, dates, datetimes,
  and list-columns sensibly.
- Numeric comparisons accept a `tolerance`, applied on the natural scale
  for dates (days) and datetimes (seconds).

### dataCompareR compatibility

- Clean-room drop-in replacements for the archived dataCompareR package
  —
  [`rCompare()`](https://thays42.github.io/datadiffr/reference/rCompare.md),
  [`generateMismatchData()`](https://thays42.github.io/datadiffr/reference/generateMismatchData.md),
  [`saveReport()`](https://thays42.github.io/datadiffr/reference/saveReport.md),
  and [`print()`](https://rdrr.io/r/base/print.html) /
  [`summary()`](https://rdrr.io/r/base/summary.html) methods — returning
  objects with the same shape, so existing scripts keep working. See
  [`vignette("migrating-from-datacomparer")`](https://thays42.github.io/datadiffr/articles/migrating-from-datacomparer.md).
