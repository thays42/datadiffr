# Pre-CRAN Roadmap

From the 2026-07-03 project roundup (seven parallel assessments:
validation, dataCompareR compat, pkgdown, performance, style, code
review, competitive positioning).

Status as of 2026-07-04: Phases 0-4 complete (Phase 4 only leaves the
optional test-hygiene split). GitHub repo renamed to thays42/datadiffr;
README, @examples, “Get started” vignette, CI + pkgdown workflows, and
URL/BugReports all shipped. Repo-side step still pending: enable GitHub
Pages so pkgdown can publish. Next is Phase 5 (CRAN submission). 547
tests passing; R CMD check clean except a local qpdf WARNING (CRAN
builders have qpdf).

## Blocking decisions

**Rename the package** — renamed to **datadiffr** (chosen 2026-07-03;
`datadiff` was taken on CRAN 2026-06-18 by an unrelated ThinkR package).
Package-internal rename done. Still user-side: rename the GitHub repo
(`gh repo rename datadiffr`) and optionally the local directory, then
update DESCRIPTION URL/BugReports to the new slug.

**Key-based matching** — decided in scope and shipped (`by =` on
[`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md)/[`diffdata()`](https://thays42.github.io/datadiffr/reference/diffdata.md)).

## Phase 0 — Hygiene — DONE

Delete
`foo()`/`bar()`/[`browser()`](https://rdrr.io/r/base/browser.html) debug
leftovers from R/diff.R.

Delete `test_debug.R` and `coverage.xml`; gitignore coverage output.

Fix renv: later 1.4.2 would not compile on Fedora 44 glibc; lockfile now
pins later 1.4.8. `make test`/`make lint` work again.

Commit the pending `.lintr` / `.gitignore` changes.

## Phase 1 — Correctness — DONE

All reproduced bugs fixed test-first (see git log for details): - \[x\]
B1 empty diff crash — `diffdata(x, x)` now reports “No differences
found”. - \[x\] B2 all-NA added/deleted rows silently dropped —
join-type rows always reported. - \[x\] B3 grouped tibbles produced
garbage — inputs ungrouped before the join. - \[x\] B4 factors with
different level sets errored — compared as character. - \[x\] B5 user
column named `.rn` clobbered — internal join key namespaced. - \[x\] B6
list-columns errored — compared element-wise via
[`identical()`](https://rdrr.io/r/base/identical.html). - \[x\] B7 raw
tidyr errors on type conflicts / no shared columns — clear cli errors. -
\[x\] B8 `context_cols` rejected bare names — selections resolved via
[`tidyselect::eval_select()`](https://tidyselect.r-lib.org/reference/eval_select.html)
at entry points (bare forwarding never chains). - \[x\] B9 truncated
differences reappeared disguised as context rows. - \[x\] B10 NA vs NaN
now compare unequal (documented; matches rCompare semantics). - \[x\]
B12
[`compare_groups()`](https://thays42.github.io/datadiffr/reference/compare_groups.md)
guards against `in_x`/`in_y` grouping columns. - \[x\] B13
[`is_equal()`](https://thays42.github.io/datadiffr/reference/is_equal.md)
honors its vector contract; errors on incompatible lengths. - \[x\] B14
tolerance applies to Date/POSIXct (days/seconds scale). - \[x\] B15
[`compare_columns()`](https://thays42.github.io/datadiffr/reference/compare_columns.md)
stable column order + schema for empty results. - \[x\] B16
`render_diff(output_file=)` errors when the target directory is
missing. - \[x\] B17 truncation message uses cli pluralization;
“differing rows” semantics documented. - \[x\] Mis-targeted diffdata
edge-case test re-pointed at the real diff path. - Note: the suspected
off-by-one at the old compare.R:106 was unreachable (truncation
guarantees a later diff exists), but the indexing was made robust anyway
during the rowSums refactor.

Remaining test gaps (fine to grow organically): - \[x\] `show_diff()`
now has direct output assertions (test-show-diff.R: block separators,
cell colouring, column borders; test-diff-class.R: B11 tolerance).

## Phase 2 — Architecture

**Key-based matching**: `by =` argument on
[`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md)
and
[`diffdata()`](https://thays42.github.io/datadiffr/reference/diffdata.md);
keys must exist in both frames and be unique per frame; output ordered
by key; keys always included in output. Positional matching remains the
default.

**checkmate validation** across all exported functions; closed gaps
(`output_file`, `max_differences >= 0`, `context_rows`
integerish/non-negative,
[`render_diff()`](https://thays42.github.io/datadiffr/reference/render_diff.md)
asserts required diff columns).

Aligned
[`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md)/[`diffdata()`](https://thays42.github.io/datadiffr/reference/diffdata.md)
argument order (formals-equality test pins it). Differing
`max_differences` defaults kept and documented (Inf vs 10).

Renamed `is_equal(tol =)` → `tolerance`.

Perf: [`apply()`](https://rdrr.io/r/base/apply.html) →
[`rowSums()`](https://rdrr.io/r/base/colSums.html)/[`colSums()`](https://rdrr.io/r/base/colSums.html)
in the mask reductions.

Dropped glue, fs, and lubridate dependencies; added checkmate, rlang,
tidyselect (all previously transitive).

**Classed diff object** (`datadiff_diff` subclass of tbl_df) carrying
`tolerance`, `n_differences`, `truncated`, and `diff_columns` as
attributes, with [`print()`](https://rdrr.io/r/base/print.html) and
[`summary()`](https://rdrr.io/r/base/summary.html) methods
(R/diff-class.R).
[`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md)
returns it; headless users get console output. **Fixes B11**:
`show_diff()` now reads the tolerance from the object instead of
re-deriving the cell mask with the default tolerance.

Renderer perf: removed the two O(n^2) kableExtra offenders —
`pack_rows()` (one call per block, replaced by a single `row_spec()`
border rule between blocks) and `column_spec()` (per-`<td>` rewrite,
replaced by a scoped `<style>` rule on the self-contained lightable
table). ~1.5k diff rows dropped from ~53s to ~7s. Remaining cost is the
`row_spec()` background calls (still O(n^2), smaller constant); a full
vectorized HTML rebuild would go further but is deferred — it changes
the whole visual path and wants interactive visual verification. Only
bites users who raise max_differences.

Decomposed `compare_diff()` into `diff_mask()` / `limit_differences()` /
`context_indices()` helpers (R/compare.R). Pure refactor; behavior
unchanged.

Optional perf (deferred, low value): replace the positional hash join
with frame padding (measured 55x on the join step alone, but the whole
compare path is already ~1s at 500k rows, so the join is not the
bottleneck; the renderer was). Not worth the rewrite risk for no
user-visible gain.

## Phase 3 — dataCompareR compatibility — DONE

**Clean-room reimplementation** (dataCompareR is Apache-2.0, this
package is MIT — no code reuse; behavior pinned by black-box probes of
dataCompareR 0.1.4). dataCompareR stays in Suggests as a parity oracle
for tests.

[`rCompare()`](https://thays42.github.io/datadiffr/reference/rCompare.md)
native comparison path returning
`c("datadiff_compare", "dataCompareRobject")` with the exact field
shapes; faithful defaults (exact equality, error on `mismatches` cap)
plus a `tolerance =` extension appended after the original arguments.
Cleaned frames ride along as an attribute for the render_diff() bridge.

[`print()`](https://rdrr.io/r/base/print.html),
[`summary()`](https://rdrr.io/r/base/summary.html) (33 fields, dynamic
column names), `print.summary` (markdown report incl. Dropped Rows
Details),
[`saveReport()`](https://thays42.github.io/datadiffr/reference/saveReport.md)
(rmarkdown, writes .Rmd/.md/.html),
[`generateMismatchData()`](https://thays42.github.io/datadiffr/reference/generateMismatchData.md)
(keyed and keyless). Documented improvement: detail tables deterministic
(sorted by \|diff\| desc) where dataCompareR sampled.

Parity test suite (test-rcompare-parity.R): field-by-field vs the real
dataCompareR on shared fixtures, skip_if_not_installed.

Bridge:
[`render_diff()`](https://thays42.github.io/datadiffr/reference/render_diff.md)
is now S3 generic with a datadiff_compare method.

Vignette: “Migrating from dataCompareR” (vignettes/).

Note: local `make check` needs qpdf installed (`sudo dnf install qpdf`)
now that the package builds vignettes; without it check reports 1
environmental WARNING. CRAN builders have qpdf.

## Phase 4 — Documentation & site

Real README (README.Rmd → README.md) — pitch, GitHub install, a live
[`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md)
example, a screenshot of the HTML report
(man/figures/README-diff-example.png, generated via headless chromium +
`magick -trim`), and an honest comparison table vs
waldo/diffdf/arsenal/compareDF/dataCompareR. README.Rmd added to
.Rbuildignore.

`@examples` for all exported functions — runnable examples on
[`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md)/[`compare_groups()`](https://thays42.github.io/datadiffr/reference/compare_groups.md)/[`compare_columns()`](https://thays42.github.io/datadiffr/reference/compare_columns.md)/[`is_equal()`](https://thays42.github.io/datadiffr/reference/is_equal.md);
`@examplesIf interactive()` on
[`diffdata()`](https://thays42.github.io/datadiffr/reference/diffdata.md)/[`render_diff()`](https://thays42.github.io/datadiffr/reference/render_diff.md)
(they open an HTML report). rcompare surface already had examples.
`checking examples ... OK`.

“Get started” vignette — `vignettes/datadiffr.Rmd` (pkgdown surfaces the
package-named vignette as the “Get started” link): core workflow,
context rows, key matching, tolerance, column comparison, HTML report.
All chunks verified against real output.

`URL:` + `BugReports:` in DESCRIPTION — repo renamed to
`thays42/datadiffr`; DESCRIPTION URL/BugReports and the README install
line point at the new slug, plus the pkgdown site URL.

CI: added `.github/workflows/R-CMD-check.yaml` (check-standard matrix)
and an R-CMD-check badge. Test-coverage workflow skipped for now (needs
a Codecov token).

pkgdown: `_pkgdown.yml` with a curated reference index (High-level API /
Comparison / Rendering / dataCompareR compatibility); `check_pkgdown()`
reports no problems. Added `.github/workflows/pkgdown.yaml` deploy
workflow. Removed the stale empty `docs/`. **Repo-side step still
needed:** enable GitHub Pages (gh-pages branch) so the pkgdown workflow
can publish.

Style pass: cli_abort in render_diff, @noRd internals, stale
globalVariables, markdown Rd bullets, test naming. (lint + air format
clean.)

Split remaining test hygiene: diffdata validation mega-test was split;
consider `skip_if_not_installed` patterns as Suggests usage grows.
(Optional, non-blocking.)

## Phase 5 — CRAN submission

Execute the package rename (repo rename still user-side; pkgdown URL
follows Phase 4).

DESCRIPTION positioning statement naming alternatives, Title-Case title,
URL/BugReports.

NEWS.md written (initial-release feature summary) and version bumped
0.0.0.9000 → 0.1.0. Plain `R CMD check` still clean (0 errors / 0 notes
/ qpdf WARNING only).

`R CMD check --as-cran` clean — expect a “New submission” NOTE and
possibly URL/spell-check NOTEs to triage. Needs qpdf installed locally
to clear the size-reduction WARNING.

cran-comments.md (document the qpdf note + any –as-cran NOTEs).

win-builder (devel + release) and rhub checks.

Submit to CRAN
([`devtools::submit_cran()`](https://devtools.r-lib.org/reference/submit_cran.html)
or the web form).

## Positioning (settled by research, for reference)

Niche: “the actively maintained package for context-aware,
report-quality HTML data diffs.” Unique among maintained packages:
configurable context rows; polished HTML report as default output.
dataCompareR archived 2026-02, compareDF in maintenance mode — the
report-oriented lane is open. Honest weaknesses to fix or disclose:
~~positional-only matching~~ (fixed: `by =`), refuses to diff on any
column difference (consider diffing the intersection), no console print
method (classed object work), aggressive `max_differences = 10` default
(documented).
