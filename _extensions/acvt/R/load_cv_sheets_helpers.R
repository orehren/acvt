# R/load_cv_sheets_helpers.R

#' Prepare sheet names and target names for loading
#'
#' This helper standardizes the `sheets_to_load` argument into a consistent internal structure.
#' It handles the different input formats (named list, unnamed vector, wildcard) so the main
#' loader function can operate on a uniform configuration.
#'
#' @param sheets_to_load The user-provided sheet configuration.
#' @param ss_input The resolved Google Sheet identifier, required for wildcard expansion.
#'
#' @return A list containing the normalized sheet names and their corresponding target names.
#' @noRd
.prepare_sheet_load_config <- function(sheets_to_load, ss_input = NULL) {

  sheet_names_to_read <- NULL
  target_list_names <- NULL

  is_special_wildcard <- is.character(sheets_to_load) && length(sheets_to_load) == 1 && sheets_to_load == "*"

  if (is_special_wildcard) {
    # When the user requests all sheets ("*"), we must first query the document metadata
    # to discover what sheets are actually available.
    if (is.null(ss_input)) {
      cli::cli_abort("Internal error: {.arg ss_input} must be provided when {.arg sheets_to_load} is \"*\".", call. = FALSE)
    }
    cli::cli_inform("Fetching all sheet names from the document...")
    sheet_names_to_read <- tryCatch({
      googlesheets4::sheet_names(ss_input)
    }, error = function(e) {
      cli::cli_abort("Failed to retrieve sheet names from the document when 'sheets_to_load = \"*\"'.", parent = e, call. = FALSE)
    })

    if (length(sheet_names_to_read) == 0) {
      cli::cli_warn("No sheets found in the document or failed to retrieve names.")
      return(list(sheet_names_to_read = character(0), target_list_names = character(0)))
    }

    # Auto-generate safe, code-friendly names for the output list since the user didn't provide any.
    target_list_names <- gsub("[^[:alnum:]_]+", "_", tolower(sheet_names_to_read))
    cli::cli_inform("Using all {length(sheet_names_to_read)} sheets found: {paste(shQuote(sheet_names_to_read), collapse = ', ')}. Target list names: {.val {target_list_names}}")

  } else {
    # Handle explicit user configurations.
    is_named_input <- rlang::is_named(sheets_to_load)
    if (is_named_input) {
      # User provided specific target names for each sheet.
      sheet_names_to_read <- names(sheets_to_load)
      target_list_names <- as.character(unlist(sheets_to_load))
    } else {
      # User provided only sheet names; auto-generate target names.
      sheet_names_to_read <- sheets_to_load
      target_list_names <- gsub("[^[:alnum:]_]+", "_", tolower(sheet_names_to_read))
      cli::cli_inform(
        "Using cleaned sheet names as names for the returned list: {.val {target_list_names}}"
      )
    }
  }

  return(list(
    sheet_names_to_read = sheet_names_to_read,
    target_list_names = target_list_names
  ))
}


#' Load data for multiple sheets iteratively
#'
#' This helper iterates over the list of sheets and fetches the data for each one.
#' It uses `purrr::map` to ensure type stability and proper error handling during the iteration.
#'
#' @param sheet_names_to_read The list of sheets to fetch.
#' @param doc_identifier The Google Sheet ID/URL.
#' @param ... Additional arguments for the reader.
#' @return A list of dataframes.
#' @noRd
.load_sheets_data <- function(sheet_names_to_read, doc_identifier, ...) {
  cli::cli_inform("Starting data loading for {length(sheet_names_to_read)} sheet(s)...")

  # Create a pre-filled version of the read function to simplify the mapping call.
  read_from_specific_doc <- purrr::partial(
    read_cv_sheet,
    doc_identifier = doc_identifier,
    ...
  )

  loaded_data_list <- purrr::map(
    sheet_names_to_read,
    ~ {
      cli::cli_inform("--> Loading sheet {.val {.x}}...")
      read_from_specific_doc(sheet_name = .x)
    }
  )

  cli::cli_inform("...Data loading finished.")
  return(loaded_data_list)
}
