# datadiffr 0.1.0

First release.

datadiffr compares two data frames and reports the differences cell by cell,
with configurable context rows around each change, as a styled self-contained
HTML report.

## Comparison

* `compare_data()` compares two data frames and returns the differences as a
  tidy data frame, matching rows by position or by key columns (`by =`), with
  configurable context rows around each change.
* `diffdata()` runs the comparison and renders it as an HTML report in the
  RStudio viewer, browser, or a file.
* `compare_columns()` reports column name and type differences, and
  `compare_groups()` compares group membership between two frames.
* `is_equal()` provides tolerance-aware, vectorized equality that handles `NA`,
  `NaN`, and infinite values, and compares factors, dates, datetimes, and
  list-columns sensibly.
* Numeric comparisons accept a `tolerance`, applied on the natural scale for
  dates (days) and datetimes (seconds).

## dataCompareR compatibility

* Clean-room drop-in replacements for the archived dataCompareR package —
  `rCompare()`, `generateMismatchData()`, `saveReport()`, and `print()` /
  `summary()` methods — returning objects with the same shape, so existing
  scripts keep working. See `vignette("migrating-from-datacomparer")`.
