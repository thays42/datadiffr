# Pre-CRAN Roadmap

From the 2026-07-03 project roundup (seven parallel assessments: validation, dataCompareR
compat, pkgdown, performance, style, code review, competitive positioning).

## Blocking decisions

- [ ] **Rename the package.** `datadiff` was taken on CRAN 2026-06-18 by an unrelated
  ThinkR package (YAML-rule data validation). Candidates: framediff, tablediff,
  diffreport, datadelta, tidydiff — check availability before choosing.
- [ ] **Decide on key-based matching (`by =` / `keys =`).** Flagged independently by the
  code review, the positioning research, and the dataCompareR analysis. Rows currently
  match strictly by row number; one inserted row misaligns everything after it. Every
  maintained competitor is key-based, and the rCompare() drop-in is dishonest without it.
  Recommendation: add it before submission.

## Phase 0 — Hygiene (minutes)

- [ ] Delete `foo()`/`bar()`/`browser()` debug leftovers from `R/diff.R:133-141`
  (uncommitted; would trip R CMD check).
- [ ] Delete or relocate `test_debug.R` and `coverage.xml` at repo root; gitignore as needed.
- [ ] Fix renv: clear the stale library dir (`~/.cache/R/renv/library/datadiff-82015fc7`)
  and `renv::restore()` — `later` fails to compile and blocks full restore; `make lint`
  and `make test` currently fail because of this.
- [ ] Commit the pending `.lintr` / `.gitignore` changes.

## Phase 1 — Correctness (all reproduced by the code review)

High severity:
- [ ] **B1** `diffdata(x, x)` (zero differences) crashes the renderer — `show_diff()` on a
  0-row diff → `subscript out of bounds` (`R/diff.R:19-29,64-74`).
- [ ] **B2** Added/deleted rows whose values are all `NA` silently vanish from the diff —
  mask ignores `.join_type` (`R/compare.R:88-96`). Silent data loss in a diff tool.
- [ ] **B3** Grouped tibbles: `row_number()` numbers per group → many-to-many join,
  garbage output (`R/compare.R:51-52`). Fix: `ungroup()` first.
- [ ] **B4** Factors with different level sets error out (`R/equal.R:34`) — compare
  `as.character()` for factors.
- [ ] **B5** A user column named `.rn` is clobbered by the join key and never compared
  (`R/compare.R:51-52`).

Medium (fix or document):
- [ ] **B7** `compare_data()` with type-conflicted / zero shared columns throws raw tidyr
  errors — guard like `diffdata()` does.
- [ ] **B8** `context_cols` rejects bare column names — use `{{ }}` not `all_of()`
  (`R/compare.R:159`; `compare_groups` does it right).
- [ ] **B9** Rows truncated by `max_differences` reappear as fake "context" showing only
  x values (`R/compare.R:106-137`).
- [ ] **B10** `NA` vs `NaN` compare as equal — decide and document (`R/equal.R:25`).
  Note: rCompare treats them as unequal.
- [ ] **B11** `show_diff()` re-runs `is_equal()` with the *default* tolerance, ignoring
  the user's (`R/diff.R:41-43`) — renderer should reuse the computed mask.
- [ ] **B12** `compare_groups()` breaks on grouping columns named `in_x`/`in_y`.
- [ ] **B6, B13-B17** (list-columns, is_equal vector contract, Date/POSIXct tolerance,
  compare_columns column-order instability, output_file silent copy failure,
  max_differences counts rows not differences) — see review notes.
- [ ] Off-by-one at `R/compare.R:106`: `(last_diff + 1):nrow(data)` counts backwards when
  the last row differs (also independently found by the profiler).

Test gaps to close alongside:
- [ ] `test-diffdata.R:71-80` is mis-targeted — accidental int/double type conflict means
  the context_rows path never runs.
- [ ] No tests at all for: `max_differences`, nonzero `context_rows` windows,
  `context_cols`, empty diff through render, vector inputs to `is_equal`, grouped
  inputs, `output_file` producing a file.

## Phase 2 — Architecture (pre-CRAN breaking changes are cheap)

- [ ] **Introduce a classed diff object** (`new_datadiff()`: diff + truncation state +
  tolerance + column metadata) with `print()`/`summary()`/`render_diff()` methods.
  Fixes B1/B9/B11 as side effects; gives headless users a console print method;
  eliminates `diffdata()`'s polymorphic return.
- [ ] **Key-based matching** in `compare_join()`/`compare_data()`/`diffdata()` (see
  blocking decision above).
- [ ] **Migrate validation to checkmate.** Already in the dependency tree transitively
  (kableExtra → htmlTable); promote to Imports. Collapses stopifnot blocks, closes real
  gaps (`output_file` unvalidated, `max_differences` sign, `context_rows`
  integer-ness). Keep hand-rolled: tidy-select args, flexdashboard guard. Consider
  `makeAssertCollection()` to report all argument errors at once.
- [ ] Align `compare_data()` vs `diffdata()` argument order and `max_differences`
  defaults (currently `Inf` vs `10`).
- [ ] Decompose `compare_diff()` (five jobs, ~90 lines) into `diff_mask()` /
  `limit_differences()` / `context_indices()`.
- [ ] Rename `is_equal(tol =)` → `tolerance` for API consistency.
- [ ] Perf one-liners: `apply(mask, 1, any)` → `rowSums(mask) > 0` (25x on that line,
  `R/compare.R:99`, also :107/:111); replace row-number hash join with frame padding
  (55x). Rcpp: evaluated and rejected — not worth it.
- [ ] Renderer perf: vectorized HTML string construction instead of kableExtra per-row
  DOM surgery (53s at ~1.5k diff rows today), or cap + warn. Only bites users who
  raise `max_differences`.
- [ ] Drop `fs` (single `path_package()` call → `system.file()`) and `glue` (single use;
  cli interpolates natively) from Imports.

## Phase 3 — dataCompareR compatibility

- [ ] **Clean-room reimplementation** (dataCompareR is Apache-2.0, this package is MIT —
  no code reuse; the contract/field names are fair game). dataCompareR stays in
  Suggests as a parity oracle for tests.
- [ ] `rCompare()` as a native comparison path (not a wrapper over `diffdata()`),
  returning class `c("datadiff_compare", "dataCompareRobject")` with the exact field
  shapes (`meta`, `colMatching`, `rowMatching$matchKeys`, `cleaninginfo`, `mismatches`,
  `matches`). Faithful defaults inside rCompare (exact equality, error on `mismatches`
  cap); datadiff-native defaults everywhere else.
- [ ] `print()`, `summary()` (~30 fields), `print.summary`, `saveReport()` (on
  rmarkdown), `generateMismatchData()`.
- [ ] Parity test suite: both packages on shared fixtures, field-by-field.
- [ ] Bridge: `render_diff()` method for the compat object (the migration carrot).
- [ ] Vignette: "Migrating from dataCompareR" (outline drafted — why migrate / quick
  start / compat surface / keyed vs row-order / known differences / extensions /
  graduating to diffdata / troubleshooting).

## Phase 4 — Documentation & site

- [ ] Real README (currently 10 bytes) via `usethis::use_readme_rmd()` — pitch, install,
  rendered `diffdata()` example with report screenshot, honest comparison table.
- [ ] `@examples` for all exported functions (currently zero anywhere);
  `@examplesIf interactive()` for `render_diff()`.
- [ ] `@keywords internal`/`@noRd` for `show_diff` (has an Rd but isn't exported);
  document or `@noRd` `col_class()`; fix stale `globalVariables` (`.rn.x`/`.rn.y`).
- [ ] "Get started" vignette (VignetteBuilder is declared but vignettes/ doesn't exist).
- [ ] `URL:` + `BugReports:` in DESCRIPTION (`usethis::use_github_links()`).
- [ ] CI: `usethis::use_github_action("check-standard")` (there is currently zero CI),
  optionally test-coverage.
- [ ] `usethis::use_pkgdown_github_pages()`; curate reference index (High-level API /
  Comparison / Utilities); remove stale empty `docs/`.
- [ ] Style nits: `stop()` → `cli::cli_abort()` in `render_diff()`; drop redundant
  `glue()` wrapper; normalize test names; split the diffdata mega-test;
  `skip_if_not_installed("lubridate")` in the test helper.

## Phase 5 — CRAN submission

- [ ] Execute the rename (repo, DESCRIPTION, pkgdown URL).
- [ ] DESCRIPTION positioning statement naming alternatives (draft exists — complements
  waldo/diffdf console output and versus/arsenal in-session tables; maintained
  alternative to compareDF (maintenance mode) and archived dataCompareR for
  report-oriented comparison).
- [ ] NEWS.md, version bump, `R CMD check --as-cran` clean, win-builder/rhub, submit.

## Positioning (settled by research, for reference)

Niche: "the actively maintained package for context-aware, report-quality HTML data
diffs." Unique among maintained packages: configurable context rows; polished HTML
report as default output. dataCompareR archived 2026-02, compareDF in maintenance
mode — the report-oriented lane is open. Honest weaknesses to fix or disclose:
positional-only matching (fix), refuses to diff on any column difference (consider
diffing the intersection), no console print (fixed by the classed object), aggressive
`max_differences = 10` default (document).
