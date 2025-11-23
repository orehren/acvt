# R/format_typst_section.R

#' Format a single value for Typst based on NA handling rules
#'
#' @param values Vector of values to format.
#' @param na_action Strategy for handling NAs (omit, keep, string).
#'
#' @return Character vector of formatted values.
#' @noRd
.format_typst_value <- function(values, na_action) {
  dplyr::case_when(
    is.na(values) & na_action == "omit"   ~ NA_character_,
    is.na(values) & na_action == "keep"   ~ "none",
    is.na(values) & na_action == "string" ~ '"NA"',
    !is.na(values)                        ~ paste0('"', .escape_typst_string(as.character(values)), '"'),
    TRUE                                  ~ NA_character_
  )
}

#' Reorder data frame columns based on a named list
#'
#' @param data Dataframe to reorder.
#' @param column_order List mapping column names to positions.
#'
#' @return Reordered dataframe.
#' @noRd
.reorder_columns_corrected <- function(data, column_order) {
  original_cols <- colnames(data)
  cols_to_order <- names(column_order)

  remaining_cols <- setdiff(original_cols, cols_to_order)

  final_cols <- remaining_cols
  sorted_order <- column_order[order(unlist(column_order))]

  for (col_name in names(sorted_order)) {
    pos <- sorted_order[[col_name]]
    final_cols <- append(final_cols, col_name, after = pos - 1)
  }

  dplyr::relocate(data, dplyr::all_of(final_cols))
}

#' Format CV section data into a Typst string
#'
#' @param data Input tibble.
#' @param typst_func The Typst function to wrap the data in.
#' @param combine_cols Columns to merge into a single field.
#' @param combine_as Name for the merged field.
#' @param combine_sep Separator for merged values.
#' @param combine_prefix Prefix for each merged value.
#' @param exclude_cols Columns to drop from the output.
#' @param column_order Explicit column ordering.
#' @param na_action How to handle missing values.
#' @param output_mode Generate row-wise function calls or a single large array.
#'
#' @return A string containing the formatted Typst code block.
#'
#' @importFrom dplyr select mutate across all_of relocate row_number
#' @importFrom tidyr unite pivot_longer
#' @importFrom rlang enquo arg_match sym
#' @importFrom tidyselect everything
#' @export
format_typst_section <- function(data,
                                 typst_func,
                                 combine_cols = NULL,
                                 combine_as = "details",
                                 combine_sep = "\\ ",
                                 combine_prefix = "- ",
                                 exclude_cols = NULL,
                                 column_order = NULL,
                                 na_action = c("omit", "keep", "string"),
                                 output_mode = c("rowwise", "array")) {

  na_action <- rlang::arg_match(na_action)
  output_mode <- rlang::arg_match(output_mode)

  combine_cols_quo <- rlang::enquo(combine_cols)
  exclude_cols_quo <- rlang::enquo(exclude_cols)

  .validate_format_typst_section_args(
    data, typst_func, combine_cols_quo, combine_as, combine_sep,
    combine_prefix, exclude_cols_quo, na_action, output_mode
  )
  .validate_column_order_corrected(column_order, data)

  if (nrow(data) == 0) {
    return("```{=typst}\n```")
  }

  combine_col_names <- evaluate_tidyselect_safely(combine_cols_quo, data, "combine_cols")
  exclude_col_names <- evaluate_tidyselect_safely(exclude_cols_quo, data, "exclude_cols")

  data_proc <- data

  if (length(combine_col_names) > 0) {
    data_proc <- data_proc |>
      dplyr::mutate(dplyr::across(dplyr::all_of(combine_col_names), ~ifelse(is.na(.), NA, paste0(combine_prefix, .)))) |>
      tidyr::unite(
        col = !!rlang::sym(combine_as),
        dplyr::all_of(combine_col_names),
        sep = combine_sep,
        na.rm = TRUE,
        remove = TRUE
      )
  }

  if (length(exclude_col_names) > 0) {
    data_proc <- dplyr::select(data_proc, -dplyr::all_of(exclude_col_names))
  }

  if (!is.null(column_order)) {
    data_proc <- .reorder_columns_corrected(data_proc, column_order)
  }

  # Vectorized transformation to Typst dictionary strings
  typst_dictionaries <- data_proc |>
    dplyr::mutate(.row_id = dplyr::row_number()) |>
    tidyr::pivot_longer(
      cols = -".row_id",
      names_to = "key",
      values_to = "value",
      values_transform = as.character
    ) |>
    dplyr::mutate(
      formatted_value = .format_typst_value(.data$value, na_action = na_action)
    ) |>
    dplyr::filter(!is.na(.data$formatted_value)) |>
    dplyr::group_by(.data$.row_id) |>
    dplyr::summarise(
      dict_str = paste0(
        "(", paste(.data$key, .data$formatted_value, sep = ": ", collapse = ", "), ")"
      )
    ) |>
    dplyr::pull(.data$dict_str)


  if (length(typst_dictionaries) == 0) {
    return(if (output_mode == "array") sprintf("```{=typst}\n%s(())\n```", typst_func) else "```{=typst}\n```")
  }

  if (output_mode == "rowwise") {
    content <- paste0(typst_func, typst_dictionaries, collapse = "\n")
    return(sprintf("```{=typst}\n%s\n```", content))
  }

  # For array mode, wrap the dictionary list in a Typst array syntax.
  content <- paste0("  ", typst_dictionaries, collapse = ",\n")
  return(sprintf("```{=typst}\n%s((\n%s\n))\n```", typst_func, content))
}
