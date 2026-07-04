## R CMD check results

`R CMD check --as-cran` passes locally with 0 errors, 0 warnings, and 0 notes
(R 4.5.2 on Fedora Linux, with qpdf and pandoc available).

This is a new release, so CRAN's incoming checks will report:

* **New submission.** This is the first submission of datadiffr.

* **Suggests or Enhances not in mainstream repositories: dataCompareR.**
  `dataCompareR` was archived from CRAN in February 2026. datadiffr provides a
  clean-room, drop-in replacement for its `rCompare()` interface, and lists
  `dataCompareR` in Suggests only as a behavioral oracle: the parity tests
  compare datadiffr's output against the real package field by field. Every use
  is guarded with `testthat::skip_if_not_installed("dataCompareR")`, so the
  package installs, loads, runs, and checks cleanly without it — the tests
  simply skip. No `dataCompareR` code is reused; the reimplementation was
  written from its documented behavior.

## Test environments

* Local: Fedora Linux, R 4.5.2 (`R CMD check --as-cran`).
* GitHub Actions: Ubuntu (R-devel, release, oldrel-1), macOS (release),
  Windows (release), via the standard r-lib/actions check-standard workflow.
* win-builder: R-devel and R-release.

## Downstream dependencies

There are no downstream dependencies, as this is a new package.
