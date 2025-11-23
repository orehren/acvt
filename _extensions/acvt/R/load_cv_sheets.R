# R/load_cv_sheets.R

#' Load multiple sheets from a Google Sheet into a named list
#'
#' @param doc_identifier The ID, URL, or name of the Google Sheets document.
#' @param sheets_to_load A configuration object (list or vector) specifying which sheets to read and how to name them.
#' @param ... Additional arguments passed to the underlying reading function.
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

  .validate_load_cv_sheets_args(doc_identifier, sheets_to_load, ...)

  ss_input <- .resolve_doc_identifier(doc_identifier)

  # Normalize the sheet configuration (wildcards, named lists, etc.) into a standard structure.
  load_config <- .prepare_sheet_load_config(sheets_to_load, ss_input = ss_input)

  if (length(load_config$sheet_names_to_read) == 0) {
    cli::cli_inform("No sheets specified or found to load. Returning an empty list.")
    return(list())
  }

  loaded_data_list_unnamed <- .load_sheets_data(
    sheet_names_to_read = load_config$sheet_names_to_read,
    doc_identifier,
    !!!list(...)
  )

  loaded_data_list_named <- purrr::set_names(
    loaded_data_list_unnamed,
    load_config$target_list_names
  )

  return(loaded_data_list_named)
}
