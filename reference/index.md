# Package index

## High-level API

Compare two data frames and render the result in one call.

- [`diffdata()`](https://thays42.github.io/datadiffr/reference/diffdata.md)
  : Diff Data Frames

## Comparison

Build and inspect diffs directly.

- [`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md)
  : Compare two data frames
- [`compare_columns()`](https://thays42.github.io/datadiffr/reference/compare_columns.md)
  : Compare column metadata between two data frames
- [`compare_groups()`](https://thays42.github.io/datadiffr/reference/compare_groups.md)
  : Compare groups between two data frames
- [`is_equal()`](https://thays42.github.io/datadiffr/reference/is_equal.md)
  : Vectorized Equality Test

## Rendering

Turn a diff into an HTML report.

- [`render_diff()`](https://thays42.github.io/datadiffr/reference/render_diff.md)
  : Render a diff in a flexdashboard

## dataCompareR compatibility

Clean-room drop-in replacements for the archived dataCompareR package,
returning objects with the same shape.

- [`rCompare()`](https://thays42.github.io/datadiffr/reference/rCompare.md)
  : Compare two data frames, dataCompareR style
- [`generateMismatchData()`](https://thays42.github.io/datadiffr/reference/generateMismatchData.md)
  : Extract the mismatching rows of a comparison
- [`saveReport()`](https://thays42.github.io/datadiffr/reference/saveReport.md)
  : Save a comparison report
- [`print(`*`<datadiff_compare>`*`)`](https://thays42.github.io/datadiffr/reference/print.datadiff_compare.md)
  : Print a dataCompareR-compatible comparison
- [`summary(`*`<datadiff_compare>`*`)`](https://thays42.github.io/datadiffr/reference/summary.datadiff_compare.md)
  [`print(`*`<summary.datadiff_compare>`*`)`](https://thays42.github.io/datadiffr/reference/summary.datadiff_compare.md)
  : Summarize a dataCompareR-compatible comparison
