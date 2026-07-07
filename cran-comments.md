## R CMD check results

`R CMD check --as-cran` passes locally with 0 errors, 0 warnings, and 0 notes
(R 4.5.2 on Fedora Linux, with qpdf and pandoc available).

This is a new release, so CRAN's incoming checks will report:

* **New submission.** This is the first submission of datadiffr.

## Test environments

* Local: Fedora Linux, R 4.5.2 (`R CMD check --as-cran`).
* GitHub Actions: Ubuntu (R-devel, release, oldrel-1), macOS (release),
  Windows (release), via the standard r-lib/actions check-standard workflow.
* win-builder: R-devel and R-release.

## Downstream dependencies

There are no downstream dependencies, as this is a new package.
