# Build the pkgdown site with internal root .md files hidden.
#
# pkgdown renders EVERY root-level .md file into the public site and offers
# no exclusion mechanism (the skip list in pkgdown:::package_mds() is
# hardcoded; .Rbuildignore is not consulted). Any root .md NOT in `public`
# below is temporarily renamed so pkgdown cannot see it, then restored when
# the build finishes -- even if it fails.
#
# Single codepath for local and CI builds:
#   - locally:  make site
#   - on CI:    .github/workflows/pkgdown.yaml runs `Rscript dev/build-site.R`
#
# To publish a new root .md file (e.g. CODE_OF_CONDUCT.md), add it to
# `public`. Anything else at the root is treated as internal by default.

main <- function() {
  public <- c(
    "README.md", "NEWS.md", "LICENSE.md", "LICENCE.md",
    "cran-comments.md", "404.md"
  )

  internal <- setdiff(list.files(".", pattern = "\\.md$"), public)
  if (length(internal) > 0) {
    hidden <- paste0(internal, ".pkgdown-bak")
    message("Hiding from pkgdown: ", paste(internal, collapse = ", "))
    stopifnot(file.rename(internal, hidden))
    on.exit(file.rename(hidden, internal), add = TRUE)
  }

  if (nzchar(Sys.getenv("GITHUB_ACTIONS"))) {
    pkgdown::build_site_github_pages(new_process = FALSE, install = FALSE)
  } else {
    pkgdown::clean_site()
    pkgdown::build_site(preview = FALSE)
  }
}

main()
