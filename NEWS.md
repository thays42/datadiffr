# datadiffr 0.1.0

First release.

datadiffr compares two data frames and reports the differences cell by cell,
with configurable context rows around each change, as a styled self-contained
HTML report.

* `compare_data()` compares two data frames — matching rows by position or by
  key columns (`by =`) — and returns a `datadiff_result`, whose `kind`
  reports whether the frames are `"identical"`, differ in their columns
  (`"schema"`), or differ in their values (`"value"`), with `print()` and
  `summary()` methods.
* Accessors extract results programmatically: `has_differences()` and
  `n_differences()` for quick checks, `get_differences()` for the differing
  rows, and `get_cell_differences()` for one row per changed cell.
* `diffdata()` runs the comparison and renders it as an HTML report in the
  RStudio viewer, browser, or a file; `render_diff()` renders an existing
  result.
* `compare_columns()` reports column name and type differences;
  `compare_groups()` compares group membership between two frames.
* `is_equal()` provides tolerance-aware, vectorized equality that handles
  `NA`, `NaN`, and infinite values, and compares factors, dates, datetimes,
  and list-columns sensibly. Tolerance applies on the natural scale for dates
  (days) and datetimes (seconds).
* Comparisons report configurable context rows around each change
  (`context_rows`), selectable context columns (`context_cols`), and a cap on
  reported differences (`max_differences`).
