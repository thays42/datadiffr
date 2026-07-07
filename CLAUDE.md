# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

datadiff is an R package for comparing and visualizing differences between data frames. It provides row-by-row comparison, column metadata diffing, context-aware output, and HTML report generation via flexdashboard.

## Common Commands

```bash
# Run all tests
make test

# Run tests for specific source files (maps to corresponding test files)
make test R/compare.R
make test R/equal.R R/diffdata.R

# Lint the package
make lint

# Run R CMD check
make check

# Generate documentation (roxygen2)
make document

# Snapshot renv (captures all deps including Suggests)
make snapshot

# Restore renv packages from lockfile
make restore

# Format package code
make format

# Build pkgdown site locally (preview only — docs/ is gitignored, CI deploys)
make site
```

## Architecture

### Core Modules

- **R/compare.R** - Main comparison logic:
  - `compare_data()` - Entry point for data frame comparison, returns diff with context rows
  - `compare_join()` - Full outer join by row number, identifies rows in x only, y only, or both
  - `compare_diff()` - Identifies differences, applies context rows, pivots for output
  - `compare_groups()` - Compares group membership between data frames
  - `compare_columns()` - Detects column name/type differences between data frames

- **R/equal.R** - `is_equal()` vectorized equality test handling NA, Inf, and numeric tolerance

- **R/diff.R** - HTML rendering:
  - `show_diff()` - Formats diff as HTML table with color coding (red=deletions, green=additions)
  - `render_diff()` - Renders diff in flexdashboard, opens in RStudio viewer or browser

- **R/diffdata.R** - `diffdata()` high-level API combining comparison and rendering

- **R/utils.R** - Helper utilities (`col_class()` for type detection)

### Data Flow

1. `diffdata()` validates inputs and checks column compatibility via `compare_columns()`
2. `compare_data()` joins frames by row number and identifies differences
3. `compare_diff()` adds context rows and pivots x/y values for display
4. `render_diff()` generates styled HTML via formattable/kableExtra and opens in viewer

### Key Dependencies

- dplyr, tidyr, purrr, stringr - Data manipulation
- formattable, kableExtra - Table styling
- flexdashboard, rmarkdown - HTML report generation
- cli, glue - User messaging

## Development Workflow

When encountering friction with commands (special flags needed, multi-step processes, non-obvious incantations):
- Propose adding **Makefile targets** for repeatable operations
- Propose updating **CLAUDE.md** with context that would help future sessions

This keeps the project self-documenting and avoids hitting the same issues repeatedly.

## Repository Conventions

- **`docs/` belongs to pkgdown and is never committed.** It is the pkgdown
  build output directory and is in `.gitignore`. The public site is built and
  deployed by CI (`.github/workflows/pkgdown.yaml`, GitHub Pages actions) on
  every push to `main`; local `make site` builds are throwaway previews. Do
  **not** put hand-written files there — pkgdown fails its build with
  `check_dest_is_pkgdown()` ("`docs` is non-empty and not [a pkgdown site]").
- **Root `.md` files are published to the website.** pkgdown renders every
  top-level `.md` file into a public site page with no exclusion config (and
  it ignores `.Rbuildignore`). `dev/build-site.R` — the single build codepath
  for both CI and `make site` — hides everything except a whitelist
  (`README`, `NEWS`, `LICENSE`, `cran-comments.md`, `404.md`) during the
  build. New internal root `.md` files are therefore excluded automatically;
  to *publish* a new root `.md` page, add it to the `public` vector in
  `dev/build-site.R`. Never build the site by calling pkgdown directly.
- **Design docs go in `dev/`, not `docs/`.** When the brainstorming /
  writing-plans skills (or any workflow) save a spec or plan, write them under
  `dev/superpowers/specs/` and `dev/superpowers/plans/` — NOT the skills'
  default `docs/superpowers/...`. `dev/` is already in `.Rbuildignore`. This
  project preference overrides the skills' default spec/plan location.

## Code Style

- Follow tidyverse style guide: snake_case for functions/variables
- Use `|>` pipe operator for data transformations
- Use roxygen2 with @param, @return, @export tags
- Input validation with `stopifnot()` for user-facing functions
- Use `rlang::abort()` or `cli::cli_alert_*` for error messaging
