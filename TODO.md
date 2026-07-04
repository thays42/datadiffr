# Pre-CRAN Roadmap

From the 2026-07-03 project roundup (seven parallel assessments: validation, dataCompareR
compat, pkgdown, performance, style, code review, competitive positioning).

Status as of 2026-07-03: Phases 0-1 complete; Phase 2 mostly complete.
R CMD check: 0 errors, 0 warnings, 0 notes. 177 tests passing.

## Blocking decisions

- [x] **Rename the package** — renamed to **datadiffr** (chosen 2026-07-03;
  `datadiff` was taken on CRAN 2026-06-18 by an unrelated ThinkR package).
  Package-internal rename done. Still user-side: rename the GitHub repo
  (`gh repo rename datadiffr`) and optionally the local directory, then
  update DESCRIPTION URL/BugReports to the new slug.
- [x] **Key-based matching** — decided in scope and shipped (`by =` on
  `compare_data()`/`diffdata()`).

## Phase 0 — Hygiene — DONE

- [x] Delete `foo()`/`bar()`/`browser()` debug leftovers from R/diff.R.
- [x] Delete `test_debug.R` and `coverage.xml`; gitignore coverage output.
- [x] Fix renv: later 1.4.2 would not compile on Fedora 44 glibc; lockfile now pins
  later 1.4.8. `make test`/`make lint` work again.
- [x] Commit the pending `.lintr` / `.gitignore` changes.

## Phase 1 — Correctness — DONE

All reproduced bugs fixed test-first (see git log for details):
- [x] B1 empty diff crash — `diffdata(x, x)` now reports "No differences found".
- [x] B2 all-NA added/deleted rows silently dropped — join-type rows always reported.
- [x] B3 grouped tibbles produced garbage — inputs ungrouped before the join.
- [x] B4 factors with different level sets errored — compared as character.
- [x] B5 user column named `.rn` clobbered — internal join key namespaced.
- [x] B6 list-columns errored — compared element-wise via `identical()`.
- [x] B7 raw tidyr errors on type conflicts / no shared columns — clear cli errors.
- [x] B8 `context_cols` rejected bare names — selections resolved via
  `tidyselect::eval_select()` at entry points (bare forwarding never chains).
- [x] B9 truncated differences reappeared disguised as context rows.
- [x] B10 NA vs NaN now compare unequal (documented; matches rCompare semantics).
- [x] B12 `compare_groups()` guards against `in_x`/`in_y` grouping columns.
- [x] B13 `is_equal()` honors its vector contract; errors on incompatible lengths.
- [x] B14 tolerance applies to Date/POSIXct (days/seconds scale).
- [x] B15 `compare_columns()` stable column order + schema for empty results.
- [x] B16 `render_diff(output_file=)` errors when the target directory is missing.
- [x] B17 truncation message uses cli pluralization; "differing rows" semantics
  documented.
- [x] Mis-targeted diffdata edge-case test re-pointed at the real diff path.
- Note: the suspected off-by-one at the old compare.R:106 was unreachable
  (truncation guarantees a later diff exists), but the indexing was made
  robust anyway during the rowSums refactor.

Remaining test gaps (fine to grow organically):
- [ ] `show_diff()` output has no direct assertions (only exercised via diffdata).

## Phase 2 — Architecture

- [x] **Key-based matching**: `by =` argument on `compare_data()` and `diffdata()`;
  keys must exist in both frames and be unique per frame; output ordered by key;
  keys always included in output. Positional matching remains the default.
- [x] **checkmate validation** across all exported functions; closed gaps
  (`output_file`, `max_differences >= 0`, `context_rows` integerish/non-negative,
  `render_diff()` asserts required diff columns).
- [x] Aligned `compare_data()`/`diffdata()` argument order (formals-equality test
  pins it). Differing `max_differences` defaults kept and documented (Inf vs 10).
- [x] Renamed `is_equal(tol =)` → `tolerance`.
- [x] Perf: `apply()` → `rowSums()`/`colSums()` in the mask reductions.
- [x] Dropped glue, fs, and lubridate dependencies; added checkmate, rlang,
  tidyselect (all previously transitive).
- [ ] **Classed diff object** (`datadiff_diff` subclass of tbl_df) carrying
  tolerance, truncation state, and diff columns as attributes, with print()
  and summary() methods. Fixes B11 (renderer re-derives the mask with the
  DEFAULT tolerance instead of the user's — still open) and gives headless
  users console output. Design this together with the rCompare compat object.
- [ ] Renderer perf/redesign: kableExtra per-row DOM surgery is O(n^1.5-2)
  (53s at ~1.5k diff rows). Rebuild table HTML via vectorized string
  construction, or cap + warn. Only bites users who raise max_differences.
- [ ] Decompose `compare_diff()` (~90 lines, five jobs) into diff_mask()/
  limit_differences()/context_indices() helpers when touching it next.
- [ ] Optional perf: replace the positional hash join with frame padding
  (measured 55x on the join step; whole compare path already ~1s at 500k rows).

## Phase 3 — dataCompareR compatibility — DONE

- [x] **Clean-room reimplementation** (dataCompareR is Apache-2.0, this package is
  MIT — no code reuse; behavior pinned by black-box probes of dataCompareR
  0.1.4). dataCompareR stays in Suggests as a parity oracle for tests.
- [x] `rCompare()` native comparison path returning
  `c("datadiff_compare", "dataCompareRobject")` with the exact field shapes;
  faithful defaults (exact equality, error on `mismatches` cap) plus a
  `tolerance =` extension appended after the original arguments. Cleaned
  frames ride along as an attribute for the render_diff() bridge.
- [x] `print()`, `summary()` (33 fields, dynamic column names), `print.summary`
  (markdown report incl. Dropped Rows Details), `saveReport()` (rmarkdown,
  writes .Rmd/.md/.html), `generateMismatchData()` (keyed and keyless).
  Documented improvement: detail tables deterministic (sorted by |diff| desc)
  where dataCompareR sampled.
- [x] Parity test suite (test-rcompare-parity.R): field-by-field vs the real
  dataCompareR on shared fixtures, skip_if_not_installed.
- [x] Bridge: `render_diff()` is now S3 generic with a datadiff_compare method.
- [x] Vignette: "Migrating from dataCompareR" (vignettes/).
- Note: local `make check` needs qpdf installed (`sudo dnf install qpdf`) now
  that the package builds vignettes; without it check reports 1 environmental
  WARNING. CRAN builders have qpdf.

## Phase 4 — Documentation & site

- [ ] Real README (currently 10 bytes) via `usethis::use_readme_rmd()` — pitch,
  install, rendered `diffdata()` example with report screenshot, honest
  comparison table.
- [ ] `@examples` for all exported functions (currently zero anywhere);
  `@examplesIf interactive()` for `render_diff()`.
- [ ] "Get started" vignette (VignetteBuilder is declared but vignettes/ doesn't
  exist).
- [ ] `URL:` + `BugReports:` in DESCRIPTION (`usethis::use_github_links()`).
- [ ] CI: `usethis::use_github_action("check-standard")` (currently zero CI),
  optionally test-coverage.
- [ ] `usethis::use_pkgdown_github_pages()`; curate reference index (High-level
  API / Comparison / Utilities); remove stale empty `docs/`.
- [x] Style pass: cli_abort in render_diff, @noRd internals, stale
  globalVariables, markdown Rd bullets, test naming. (lint + air format clean.)
- [ ] Split remaining test hygiene: diffdata validation mega-test was split;
  consider `skip_if_not_installed` patterns as Suggests usage grows.

## Phase 5 — CRAN submission

- [x] Execute the package rename (repo rename still user-side; pkgdown URL
  follows Phase 4).
- [x] DESCRIPTION positioning statement naming alternatives, Title-Case
  title, URL/BugReports.
- [ ] NEWS.md, version bump, `R CMD check --as-cran` clean, win-builder/rhub,
  submit.

## Positioning (settled by research, for reference)

Niche: "the actively maintained package for context-aware, report-quality HTML
data diffs." Unique among maintained packages: configurable context rows;
polished HTML report as default output. dataCompareR archived 2026-02,
compareDF in maintenance mode — the report-oriented lane is open. Honest
weaknesses to fix or disclose: ~~positional-only matching~~ (fixed: `by =`),
refuses to diff on any column difference (consider diffing the intersection),
no console print method (classed object work), aggressive `max_differences = 10`
default (documented).
