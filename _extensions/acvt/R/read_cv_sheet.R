# R/read_cv_sheet.R

#' Read a specific sheet from a Google Sheet for CV data
#'
#' @param doc_identifier The ID, URL, or name of the Google Sheets document.
#' @param sheet_name The specific tab to read.
#' @param na_strings Strings to treat as NA.
#' @param col_types Column type specification.
#' @param trim_ws Whether to trim whitespace.
#'
#' @return A tibble with the sheet's data.
#'
#' @importFrom googlesheets4 read_sheet gs4_get as_sheets_id
#'
#' @export
read_cv_sheet <- function(doc_identifier,
                          sheet_name,
                          na_strings = c("", "NA", "N/A"),
                          col_types = NULL,
                          trim_ws = TRUE) {

  .validate_read_cv_sheet_args(
    doc_identifier, sheet_name, na_strings, col_types, trim_ws
  )

  ss_input <- .resolve_doc_identifier(doc_identifier)

  sheet_data <- .read_sheet_data(
    ss_input, sheet_name, na_strings, col_types, trim_ws
  )

  doc_id_for_msg <- tryCatch(
    googledrive::as_id(ss_input),
    error = function(e) "UNKNOWN_ID"
  )
  sheet_data <- .check_read_result(sheet_data, sheet_name, doc_id_for_msg)

  return(sheet_data)
}
