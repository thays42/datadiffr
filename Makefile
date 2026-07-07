# This Makefile provides a 'test' target to run R tests.
#
# Usage:
#   make test          -> Runs all tests using devtools::test()
#   make test R/foo.R  -> Runs a specific test file using testthat::test_file()
#   make test R/foo.R R/bar.R -> Runs multiple specific test files

# .PHONY declares the 'test' target as phony. This tells Make that 'test' is
# not a file that will be created by the rule. This is important to prevent
# conflicts if a file named 'test' ever exists in the directory, and it also
# improves performance slightly as Make won't check for a file named 'test'.
.PHONY: test lint check document snapshot restore format site

# Capture all command-line arguments passed to Make.
# For example, if you run `make test R/file.R`, MAKECMDGOALS will be "test R/file.R".
ARGS := $(MAKECMDGOALS)

# Filter out the target name ('test') from the arguments.
# Whatever remains is treated as the list of files to test.
# If no files are passed, this variable will be empty.
FILES := $(filter-out test,$(ARGS))

# The primary test target.
test:
ifeq ($(strip $(FILES)),)
	@echo "Running all tests..."
	@R -s -e "devtools::test()"
else
	@echo "Running tests for specific files: $(FILES)"
	@for file in $(FILES); do \
		echo "--> Testing $$file"; \
		R -s -e "testthat::test_file('$$file')"; \
	done
endif

lint:
	@echo "Running linting..."
	@R -s -e "lintr::lint_package()"

check:
	@echo "Running checks..."
	@R -s -e "devtools::check()"

document:
	@echo "Running document..."
	@R -s -e "devtools::document()"

snapshot:
	@echo "Snapshotting renv (including Suggests)..."
	@R -s -e "renv::snapshot(type = 'all')"

restore:
	@echo "Restoring renv packages..."
	@R -s -e "renv::restore()"

format:
	@echo "Formatting package..."
	@air format .

# Build the pkgdown site locally (preview only; docs/ is gitignored and the
# real site is built + deployed by CI). Uses dev/build-site.R so internal
# root .md files (CLAUDE.md, TODO.md, ...) are excluded, same as CI.
site:
	@echo "Building pkgdown site..."
	@Rscript dev/build-site.R