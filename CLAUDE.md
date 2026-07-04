# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## Project Overview

datadiff is an R package for comparing and visualizing differences
between data frames. It provides row-by-row comparison, column metadata
diffing, context-aware output, and HTML report generation via
flexdashboard.

## Common Commands

``` bash
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
```

## Architecture

### Core Modules

- **R/compare.R** - Main comparison logic:

  - [`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md) -
    Entry point for data frame comparison, returns diff with context
    rows
  - `compare_join()` - Full outer join by row number, identifies rows in
    x only, y only, or both
  - `compare_diff()` - Identifies differences, applies context rows,
    pivots for output
  - [`compare_groups()`](https://thays42.github.io/datadiffr/reference/compare_groups.md) -
    Compares group membership between data frames
  - [`compare_columns()`](https://thays42.github.io/datadiffr/reference/compare_columns.md) -
    Detects column name/type differences between data frames

- **R/equal.R** -
  [`is_equal()`](https://thays42.github.io/datadiffr/reference/is_equal.md)
  vectorized equality test handling NA, Inf, and numeric tolerance

- **R/diff.R** - HTML rendering:

  - `show_diff()` - Formats diff as HTML table with color coding
    (red=deletions, green=additions)
  - [`render_diff()`](https://thays42.github.io/datadiffr/reference/render_diff.md) -
    Renders diff in flexdashboard, opens in RStudio viewer or browser

- **R/diffdata.R** -
  [`diffdata()`](https://thays42.github.io/datadiffr/reference/diffdata.md)
  high-level API combining comparison and rendering

- **R/utils.R** - Helper utilities (`col_class()` for type detection)

### Data Flow

1.  [`diffdata()`](https://thays42.github.io/datadiffr/reference/diffdata.md)
    validates inputs and checks column compatibility via
    [`compare_columns()`](https://thays42.github.io/datadiffr/reference/compare_columns.md)
2.  [`compare_data()`](https://thays42.github.io/datadiffr/reference/compare_data.md)
    joins frames by row number and identifies differences
3.  `compare_diff()` adds context rows and pivots x/y values for display
4.  [`render_diff()`](https://thays42.github.io/datadiffr/reference/render_diff.md)
    generates styled HTML via formattable/kableExtra and opens in viewer

### Key Dependencies

- dplyr, tidyr, purrr, stringr - Data manipulation
- formattable, kableExtra - Table styling
- flexdashboard, rmarkdown - HTML report generation
- cli, glue - User messaging

## Development Workflow

When encountering friction with commands (special flags needed,
multi-step processes, non-obvious incantations): - Propose adding
**Makefile targets** for repeatable operations - Propose updating
**CLAUDE.md** with context that would help future sessions

This keeps the project self-documenting and avoids hitting the same
issues repeatedly.

## Code Style

- Follow tidyverse style guide: snake_case for functions/variables
- Use `|>` pipe operator for data transformations
- Use roxygen2 with @param, @return, @export tags
- Input validation with
  [`stopifnot()`](https://rdrr.io/r/base/stopifnot.html) for user-facing
  functions
- Use [`rlang::abort()`](https://rlang.r-lib.org/reference/abort.html)
  or `cli::cli_alert_*` for error messaging
