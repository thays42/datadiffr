#' Collapse a column's class vector into a single string
#' @noRd
col_class <- function(x) {
  x |>
    class() |>
    paste0(collapse = "/")
}

utils::globalVariables(c(
  ".row",
  ".join_type",
  ".diff_type",
  ".source",
  ".rn",
  ".block",
  ".__datadiff_rn__"
))
