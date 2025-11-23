# R/validation_helpers.R

#' Validate arguments for create_publication_list
#'
#' This helper ensures that all inputs required for generating the publication list
#' are present and valid before the main logic attempts to process them.
#' This prevents downstream errors in the complex citation processing pipeline.
#'
#' @param bib_file Path to the bibliography file.
#' @param author_name Name of the author to highlight.
#' @param csl_file Path to the citation style language file.
#' @param group_labels Mapping of type codes to display labels.
#' @param default_label Fallback label for uncategorized items.
#' @param group_order Explicit ordering of the groups.
#' @param pandoc_path Custom path to the pandoc executable.
#' @param author_highlight_markup Typst template string for highlighting.
#' @param typst_func_name Name of the typst function to generate.
#'
#' @return `TRUE` invisibly on success.
#' @noRd
.validate_create_publication_list_args <- function(
    bib_file, author_name, csl_file, group_labels, default_label,
    group_order, pandoc_path, author_highlight_markup, typst_func_name) {
  checkmate::assert_file_exists(bib_file, extension = "bib")
  checkmate::assert_string(author_name, min.chars = 1)
  checkmate::assert_file_exists(csl_file, extension = "csl")
  checkmate::assert_character(group_labels, min.len = 1, names = "unique")
  checkmate::assert_string(default_label, min.chars = 1)
  if (!is.null(group_order)) {
    checkmate::assert_character(group_order, unique = TRUE)
  }
  if (!is.null(pandoc_path)) {
    checkmate::assert_string(pandoc_path, min.chars = 1)
  }
  checkmate::assert_string(
    author_highlight_markup,
    pattern = "%s"
  )
  checkmate::assert_string(
    typst_func_name,
    pattern = "^[a-zA-Z0-9_-]+$"
  )
  invisible(TRUE)
}

#' Validate arguments for format_typst_section
#'
#' This helper validates the data frame and formatting parameters before they are used
#' to generate Typst code. It ensures that column selection and string formatting options
#' are consistent with the expected output structure.
#'
#' @param data Input data frame.
#' @param typst_func Target Typst function name.
#' @param combine_cols Columns to merge.
#' @param combine_as Resulting column name.
#' @param combine_sep Separator for merged values.
#' @param combine_prefix Prefix for merged values.
#' @param exclude_cols Columns to remove.
#' @param na_action NA handling strategy.
#' @param output_mode Output format (rowwise vs array).
#'
#' @return `TRUE` invisibly on success.
#' @noRd
.validate_format_typst_section_args <- function(
    data, typst_func, combine_cols, combine_as, combine_sep,
    combine_prefix, exclude_cols, na_action, output_mode) {
  checkmate::assert_data_frame(data)
  checkmate::assert_string(typst_func, pattern = "^#")
  checkmate::assert_string(combine_as)
  checkmate::assert_string(combine_sep)
  checkmate::assert_string(combine_prefix)
  checkmate::assert_choice(na_action, c("omit", "keep", "string"))
  checkmate::assert_choice(output_mode, c("rowwise", "array"))
  invisible(TRUE)
}

#' Validate arguments for load_cv_sheets
#'
#' Checks the structural integrity of the sheet loading configuration.
#' It ensures the document ID and sheet list are in a valid format before any API calls are made.
#'
#' @noRd
.validate_load_cv_sheets_args <- function(doc_identifier, sheets_to_load, ...) {
  checkmate::assert_string(doc_identifier, min.chars = 1)

  if (is.character(sheets_to_load)) {
    checkmate::assert_character(sheets_to_load, min.chars = 1, min.len = 1)
  } else if (rlang::is_named(sheets_to_load)) {
    checkmate::assert_list(sheets_to_load, types = "character", names = "unique")
  } else {
    checkmate::assert_list(sheets_to_load, types = "character")
  }
}

#' Validate arguments for read_cv_sheet
#'
#' Validates the parameters for reading a single sheet, including the name, type specs, and NA handling options.
#'
#' @noRd
.validate_read_cv_sheet_args <- function(
    doc_identifier, sheet_name, na_strings, col_types, trim_ws) {
  checkmate::assert_string(doc_identifier, min.chars = 1)
  checkmate::assert_string(sheet_name, min.chars = 1)
  checkmate::assert_character(na_strings, null.ok = FALSE)
  if (!is.null(col_types)) {
    checkmate::assert_atomic(col_types)
  }
  checkmate::assert_logical(trim_ws, len = 1, any.missing = FALSE)
}

#' Find and validate an executable, returning its path
#'
#' This helper verifies that a required external tool (like Pandoc) exists on the system.
#' It prioritizes a user-provided path but falls back to the system PATH, failing fast if the tool is missing.
#'
#' @param exec_name Executable name.
#' @param path_arg Optional explicit path.
#' @param arg_name Name of the argument for error reporting.
#'
#' @return The absolute path to the executable.
#' @noRd
.validate_executable_found <- function(exec_name, path_arg = NULL, arg_name = "path_arg") {
  if (!is.null(path_arg)) {
    if (!checkmate::test_file_exists(path_arg)) {
      cli::cli_abort(
        c(
          "x" = "Executable not found at the path you provided.",
          " " = "Argument: {.arg {arg_name}}",
          " " = "Path: {.path {path_arg}}"
        ),
        call = NULL
      )
    }
    return(path_arg)
  }

  exec_path <- Sys.which(exec_name)
  if (exec_path == "") {
    cli::cli_abort(
      c(
        "x" = "{.val {exec_name}} executable not found in your system's PATH.",
        "i" = "Please install {exec_name} or provide a direct path via the {.arg {arg_name}} argument."
      ),
      call = NULL
    )
  }
  exec_path
}

#' Validate the corrected column_order argument
#'
#' Checks that the user-supplied column ordering is valid: existing columns, unique positions, and positive integers.
#' This ensures reordering operations don't fail silently or produce corrupted data.
#'
#' @param column_order Reordering list.
#' @param data Target dataframe.
#'
#' @return `TRUE` invisibly on success.
#' @noRd
.validate_column_order_corrected <- function(column_order, data) {
  if (is.null(column_order)) {
    return(invisible(TRUE))
  }

  checkmate::assert_list(column_order, names = "unique")

  specified_cols <- names(column_order)
  missing_cols <- setdiff(specified_cols, colnames(data))
  if (length(missing_cols) > 0) {
    cli::cli_abort(
      c(
        "x" = "Columns specified in {.arg column_order} not found in the data.",
        "i" = "Missing column{?s}: {.val {missing_cols}}"
      ),
      call = NULL
    )
  }

  order_indices <- unlist(column_order)
  checkmate::assert_numeric(order_indices, lower = 1, unique = TRUE, any.missing = FALSE)
  if (any(order_indices %% 1 != 0)) {
    cli::cli_abort(
      c(
        "x" = "The values of the {.arg column_order} list must be positive integers.",
        "i" = "Example: {.code list(\"col_a\" = 1, \"col_b\" = 3)}"
      ),
      call = NULL
    )
  }

  invisible(TRUE)
}
