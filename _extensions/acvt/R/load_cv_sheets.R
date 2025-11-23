# R/load_cv_sheets.R

#' Load multiple sheets from a Google Sheet into a named list
#'
#' This function acts as a high-level orchestrator to fetch multiple datasets
#' from a single Google Sheets document. It abstracts away the iteration logic
#' and ensures all data is returned in a consistent, named list format for downstream processing.
#'
#' @param doc_identifier The ID, URL, or name of the Google Sheets document.
#' @param sheets_to_load A configuration object (list or vector) specifying which sheets to read and how to name them.
#' @param ... Additional arguments passed to the underlying reading function (e.g., for type handling).
#'
#' @return A named list of tibbles containing the requested data.
#'
#' @importFrom purrr map set_names map_chr
#' @importFrom rlang list2
#'
#' @export
load_cv_sheets <- function(doc_identifier,
                           sheets_to_load,
                           ...) {

  # Ensure all inputs are valid before attempting any API calls to prevent expensive failures.
  .validate_load_cv_sheets_args(doc_identifier, sheets_to_load, ...)

  ss_input <- .resolve_doc_identifier(doc_identifier)

  # Normalize the user's sheet configuration into a standardized format (names vs. targets)
  # to simplify the loading logic downstream.
  load_config <- .prepare_sheet_load_config(sheets_to_load, ss_input = ss_input)

  if (length(load_config$sheet_names_to_read) == 0) {
    cli::cli_inform("No sheets specified or found to load. Returning an empty list.")
    return(list())
  }

  # Perform the actual data loading for each configured sheet.
  # We delegate this to a helper to keep the main function focused on orchestration.
  loaded_data_list_unnamed <- .load_sheets_data(
    sheet_names_to_read = load_config$sheet_names_to_read,
    doc_identifier,
    !!!list(...)
  )

  # Apply the user-defined (or auto-generated) names to the result list
  # to ensure the data is accessible by meaningful keys in the final output.
  loaded_data_list_named <- purrr::set_names(
    loaded_data_list_unnamed,
    load_config$target_list_names
  )

  return(loaded_data_list_named)
}
