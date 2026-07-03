#' Compare two data frames
#'
#' @param x,y Data frames to compare.
#' @param by Optional character vector of key columns to match rows on, like
#'   a join. Key columns must exist in both data frames and uniquely identify
#'   rows in each. When `NULL` (the default), rows are matched by position
#'   (row number). With `by`, the output is ordered by the key columns and
#'   key columns are always included in the output.
#' @param context_rows Integer vector of length two indicating the number of context
#'   rows to include before and after a difference row.
#' @param context_cols <[`tidy-select`][dplyr_tidy_select]> Columns to include as context.
#' @param max_differences Maximum number of differing rows to report. When
#'   exceeded, only the first `max_differences` differing rows are returned
#'   (with a message).
#' @param tolerance Numeric tolerance for comparing numeric values.
#' @details
#' Rows are matched by position (row number), or by key columns when `by`
#' is given. `x` and `y` must share at least one column, and shared columns
#' must have compatible types; otherwise an error is thrown. Rows present
#' in only one data frame are always reported as differences.
#' @return A data frame containing differences between `x` and `y` with the
#'   following columns:
#'   * `.row` - The row number from the original data frames
#'   * `.join_type` - Whether the row is in `"x"`, `"y"`, or `"both"`
#'   * `.diff_type` - Whether the row is a `"diff"` or `"context"` row
#'   * `.source` - For diff rows, whether this is the `"x"` or `"y"` version;
#'     `NA` for context rows
#'
#'   Plus the original data columns (context columns and columns with differences).
#' @export
compare_data <- function(
  x,
  y,
  by = NULL,
  context_rows = c(3L, 3L),
  context_cols = everything(),
  max_differences = Inf,
  tolerance = .Machine$double.eps^0.5
) {
  checkmate::assert_data_frame(x)
  checkmate::assert_data_frame(y)
  checkmate::assert_character(
    by,
    min.len = 1,
    any.missing = FALSE,
    unique = TRUE,
    null.ok = TRUE
  )
  if (!is.null(by)) {
    checkmate::assert_subset(by, names(x))
    checkmate::assert_subset(by, names(y))
  }
  checkmate::assert_integerish(
    context_rows,
    len = 2,
    lower = 0,
    any.missing = FALSE
  )
  checkmate::assert_number(max_differences, lower = 0)
  checkmate::assert_number(tolerance, lower = 0)

  if (length(intersect(names(x), names(y))) == 0) {
    cli::cli_abort("`x` and `y` have no columns in common.")
  }
  col_diff <- compare_columns(x, y)
  conflicts <- col_diff[col_diff$.diff == "type conflict", ]
  if (nrow(conflicts) > 0) {
    cli::cli_abort(c(
      "`x` and `y` have column type conflicts.",
      set_names(
        paste0(
          conflicts$column,
          ": ",
          conflicts$x_type,
          " vs ",
          conflicts$y_type
        ),
        rep("x", nrow(conflicts))
      )
    ))
  }

  # resolve the tidy-select expression against x so it can be passed as
  # plain column names; selections do not survive bare forwarding between
  # functions
  context_cols <- names(
    tidyselect::eval_select(rlang::enquo(context_cols), data = x)
  )
  if (!is.null(by)) {
    # key columns identify rows in the report, so always include them
    context_cols <- union(by, context_cols)
  }

  compare_join(x, y, by = by) |>
    compare_diff(
      context_rows = context_rows,
      context_cols = context_cols,
      max_differences = max_differences,
      tolerance = tolerance
    )
}

compare_join <- function(x, y, by = NULL) {
  if (is.null(by)) {
    compare_join_positional(x, y)
  } else {
    compare_join_keyed(x, y, by)
  }
}

compare_join_positional <- function(x, y) {
  full_join(
    x = mutate(ungroup(x), .__datadiff_rn__ = row_number()),
    y = mutate(ungroup(y), .__datadiff_rn__ = row_number()),
    by = join_by(.__datadiff_rn__),
    suffix = c(".__datadiff_x__", ".__datadiff_y__"),
    keep = TRUE
  ) |>
    mutate(
      .row = coalesce(
        .data[[".__datadiff_rn__.__datadiff_x__"]],
        .data[[".__datadiff_rn__.__datadiff_y__"]]
      ),
      .join_type = case_when(
        !is.na(.data[[".__datadiff_rn__.__datadiff_x__"]]) &
          !is.na(.data[[".__datadiff_rn__.__datadiff_y__"]]) ~
          "both",
        !is.na(.data[[".__datadiff_rn__.__datadiff_x__"]]) ~ "x",
        !is.na(.data[[".__datadiff_rn__.__datadiff_y__"]]) ~ "y"
      ),
      .before = everything()
    ) |>
    select(
      -all_of(c(
        ".__datadiff_rn__.__datadiff_x__",
        ".__datadiff_rn__.__datadiff_y__"
      ))
    )
}

compare_join_keyed <- function(x, y, by) {
  if (anyDuplicated(x[by]) > 0) {
    cli::cli_abort("`by` columns must uniquely identify rows in `x`.")
  }
  if (anyDuplicated(y[by]) > 0) {
    cli::cli_abort("`by` columns must uniquely identify rows in `y`.")
  }

  full_join(
    x = mutate(ungroup(x), .__datadiff_in_x__ = TRUE),
    y = mutate(ungroup(y), .__datadiff_in_y__ = TRUE),
    by = by,
    suffix = c(".__datadiff_x__", ".__datadiff_y__")
  ) |>
    arrange(pick(all_of(by))) |>
    mutate(
      .row = row_number(),
      .join_type = case_when(
        !is.na(.data$.__datadiff_in_x__) &
          !is.na(.data$.__datadiff_in_y__) ~
          "both",
        !is.na(.data$.__datadiff_in_x__) ~ "x",
        .default = "y"
      ),
      .before = everything()
    ) |>
    select(-all_of(c(".__datadiff_in_x__", ".__datadiff_in_y__")))
}

compare_diff <- function(
  data,
  context_rows = c(3L, 3L),
  context_cols = character(),
  max_differences = Inf,
  tolerance = .Machine$double.eps^0.5
) {
  # identify columns to compare
  compare_cols <- names(data) |>
    str_subset("\\.__datadiff_(x|y)__$") |>
    str_remove("\\.__datadiff_(x|y)__$") |>
    unique()

  # identify rows with differences
  mask <- matrix(FALSE, nrow = nrow(data), ncol = length(compare_cols))
  colnames(mask) <- compare_cols
  for (column in compare_cols) {
    mask[, column] <- !is_equal(
      data[[paste0(column, ".__datadiff_x__")]],
      data[[paste0(column, ".__datadiff_y__")]],
      tolerance = tolerance
    )
  }

  # limit to max differences
  # rows only in x or only in y are always differences, even if their
  # compared values are all NA
  row_mask <- rowSums(mask) > 0 | data$.join_type != "both"
  all_diff_rows <- which(row_mask)
  n_differences <- sum(row_mask)
  if (n_differences > max_differences) {
    cli::cli_alert_info(
      "{n_differences} differing row{?s} found. Reporting the first {max_differences} only."
    )
    last_diff <- max(head(which(row_mask), max_differences))
    row_mask[seq_along(row_mask) > last_diff] <- FALSE
    col_mask <- colSums(mask[seq_len(last_diff), , drop = FALSE]) > 0
  } else {
    col_mask <- colSums(mask) > 0
  }
  diff_columns <- compare_cols[col_mask]

  # identify context rows
  context_mask <- rep(FALSE, nrow(data))
  diff_indices <- which(row_mask)
  n_diffs <- length(diff_indices)
  ctx_back <- rep(context_rows[1] + 1, times = n_diffs)
  ctx_fwd <- rep(context_rows[2] + 1, times = n_diffs)
  context_mask[pmax(
    sequence(ctx_back, from = diff_indices, by = -1L),
    1L
  )] <- TRUE
  context_mask[pmin(
    sequence(ctx_fwd, from = diff_indices, by = 1L),
    nrow(data)
  )] <- TRUE
  # exclude every differing row, including rows hidden by max_differences;
  # a truncated difference must not reappear disguised as a context row
  context_mask[all_diff_rows] <- FALSE

  # pull context rows
  # context rows are pulled from the `x` data frame
  # drop `y` data frame columns and de-suffix `x` data frame columns
  context_data <- data[context_mask, ] |>
    mutate(.diff_type = "context") |>
    select(!all_of(str_c(compare_cols, ".__datadiff_y__"))) |>
    rename_with(\(x) str_remove(x, "\\.__datadiff_x__$"))

  # pull data rows
  diff_data <- data[row_mask, ]
  if (length(compare_cols) == 0) {
    # only key columns are shared, so differing rows exist in one frame only
    diff_data <- mutate(diff_data, .source = .data$.join_type)
  } else {
    diff_data <- diff_data |>
      # pivot so that `x` rows stacked on `y` rows.
      pivot_longer(
        ends_with(".__datadiff_x__") | ends_with(".__datadiff_y__"),
        names_to = c(".value", ".source"),
        names_pattern = "^(.+)\\.__datadiff_(x|y)__$"
      ) |>
      # remove empty rows representing rows in x not in y or vice versa
      filter(.data$.join_type == "both" | .data$.join_type == .data$.source)
  }

  diff_data |>
    mutate(.diff_type = "diff") |>
    # add context rows, arrange columns and rows for output
    bind_rows(context_data) |>
    select(
      .row,
      .join_type,
      .diff_type,
      .source,
      all_of(context_cols),
      all_of(diff_columns)
    ) |>
    arrange(.data$.row)
}

#' Compare groups between two data frames
#'
#' @param x,y Data frames to compare
#' @param group_cols <[`tidy-select`][dplyr_tidy_select]> Columns to use for grouping
#' @return A data frame containing the grouping columns and two additional columns,
#'   `in_x` and `in_y`, which are TRUE if the group values are in the corresponding
#'   data frame and FALSE otherwise. Records where both `in_x` and `in_y` are TRUE
#'   are excluded from the output.
#' @export
compare_groups <- function(x, y, group_cols) {
  checkmate::assert_data_frame(x)
  checkmate::assert_data_frame(y)

  x_groups <- x |> select({{ group_cols }}) |> distinct()
  if (any(c("in_x", "in_y") %in% names(x_groups))) {
    cli::cli_abort(
      "`group_cols` can't include columns named `in_x` or `in_y`."
    )
  }
  x_groups <- mutate(x_groups, in_x = TRUE)
  y_groups <- y |> select({{ group_cols }}) |> distinct() |> mutate(in_y = TRUE)
  join_cols <- setdiff(names(x_groups), "in_x")

  full_join(x_groups, y_groups, by = join_cols) |>
    filter(is.na(.data$in_x) | is.na(.data$in_y)) |>
    mutate(
      in_x = replace_na(.data$in_x, FALSE),
      in_y = replace_na(.data$in_y, FALSE)
    ) |>
    arrange(pick(all_of(join_cols)))
}

#' Compare column metadata between two data frames
#'
#' @param x,y Data frames to compare.
#' @return A data frame with the following columns:
#'   * `.diff` - The type of difference: `"in x only"`, `"in y only"`,
#'     or `"type conflict"`
#'   * `column` - The column name
#'   * `x_type` - The column type in `x` (if applicable)
#'   * `y_type` - The column type in `y` (if applicable)
#'
#'   Returns an empty data frame if there are no differences.
#' @export
compare_columns <- function(x, y) {
  checkmate::assert_data_frame(x)
  checkmate::assert_data_frame(y)

  rc <- tibble(
    .diff = character(),
    column = character(),
    x_type = character(),
    y_type = character()
  )

  # column names
  x_names <- names(x)
  x_types <- map_chr(x, col_class) |>
    set_names(x_names)
  y_names <- names(y)
  y_types <- map_chr(y, col_class) |>
    set_names(y_names)

  if (!setequal(x_names, y_names)) {
    x_only_names <- setdiff(x_names, y_names)
    if (length(x_only_names) > 0) {
      rc <- bind_rows(
        rc,
        tibble(
          .diff = "in x only",
          column = x_only_names,
          x_type = x_types[x_only_names]
        )
      )
    }
    y_only_names <- setdiff(y_names, x_names)
    if (length(y_only_names) > 0) {
      rc <- bind_rows(
        rc,
        tibble(
          .diff = "in y only",
          column = y_only_names,
          y_type = y_types[y_only_names]
        )
      )
    }
  }

  names_in_both <- intersect(x_names, y_names)

  # column types
  diff_types <- names(which(x_types[names_in_both] != y_types[names_in_both]))
  rc <- bind_rows(
    rc,
    tibble(
      .diff = "type conflict",
      column = diff_types,
      x_type = x_types[diff_types],
      y_type = y_types[diff_types]
    )
  )

  rc |>
    mutate(across(everything(), unname))
}
