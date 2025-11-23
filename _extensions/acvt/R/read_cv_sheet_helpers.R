# R/read_cv_sheet_helpers.R

#' Attempt to resolve identifier as a URL
#'
#' This helper extracts the Sheet ID from a full URL, simplifying the input for downstream API calls.
#'
#' @param doc_identifier The potential URL string.
#' @return The extracted Sheet ID string.
#' @noRd
.resolve_identifier_as_url <- function(doc_identifier) {
  resolved_id <- googlesheets4::as_sheets_id(doc_identifier)

  cli::cli_inform("Interpreted identifier as URL, extracted ID: {resolved_id}")
  return(resolved_id)
}


#' Attempt to resolve identifier as a Sheet ID
#'
#' This helper checks if the input string plausibly resembles a Sheet ID.
#' This allows us to skip expensive Drive searches if the user likely provided a direct ID.
#'
#' @param doc_identifier The potential ID string.
#' @return The input string if it looks like an ID, otherwise NULL.
#' @noRd
.resolve_identifier_as_id <- function(doc_identifier) {
  # We use a heuristic check (no protocol, no spaces, length) to guess if it's an ID.
  is_potential_id <- !grepl("://", doc_identifier, fixed = TRUE) &&
    !grepl("[[:space:]/]", doc_identifier) &&
    nchar(doc_identifier) > 30

  if (is_potential_id) {
    return(doc_identifier)
  } else {
    return(NULL)
  }
}


#' Attempt to resolve identifier as a Sheet Name using Google Drive search
#'
#' This helper searches Google Drive for a file with the given name.
#' It handles the case where the user provides a human-readable name instead of an ID.
#'
#' @param doc_identifier The potential Sheet name string.
#' @return A 1-row dribble if a unique match is found. Aborts otherwise.
#' @noRd
.resolve_identifier_as_name <- function(doc_identifier) {
  cli::cli_inform("Interpreting identifier as a name, searching Google Drive for: {.val {doc_identifier}}")

  found_files_dribble <- googledrive::drive_find(
    q = sprintf(
      "name = '%s' and mimeType = 'application/vnd.google-apps.spreadsheet'",
      gsub("'", "\\\\'", doc_identifier)
    ),
    n_max = 2
  )

  # Fail fast if the name is ambiguous or not found.
  if (nrow(found_files_dribble) == 0) {
    cli::cli_abort("No Google Sheet document found with the exact name {.val {doc_identifier}}.", call. = FALSE)
  }

  if (nrow(found_files_dribble) > 1) {
    cli::cli_abort(
      c("Multiple Google Sheet documents found with the name {.val {doc_identifier}}.",
        "i" = "Please use the unique document ID or URL instead."
      ),
      call. = FALSE
    )
  }

  cli::cli_inform("Found unique document with name {.val {doc_identifier}}, using its dribble representation.")
  return(found_files_dribble)
}


#' Resolve document identifier to a gs4-compatible object
#'
#' This dispatcher determines the type of identifier (URL, ID, or Name) and calls the appropriate resolution logic.
#' It ensures the main loading function receives a consistent identifier object regardless of user input format.
#'
#' @param doc_identifier User-provided identifier.
#' @return The resolved identifier (string ID or dribble).
#' @noRd
.resolve_doc_identifier <- function(doc_identifier) {

  is_url <- grepl("://", doc_identifier, fixed = TRUE)
  if (is_url) {
    resolved_input <- .resolve_identifier_as_url(doc_identifier)
    return(resolved_input)
  }

  resolved_id <- .resolve_identifier_as_id(doc_identifier)
  if (!is.null(resolved_id)) {
    return(resolved_id)
  }

  resolved_dribble <- .resolve_identifier_as_name(doc_identifier)
  return(resolved_dribble)
}


#' Read the raw data from the sheet
#'
#' This helper wraps the API call to fetch data, isolating the external dependency.
#'
#' @param ss_input Resolved identifier.
#' @param sheet_name Sheet to read.
#' @param na_strings NA handling.
#' @param col_types Column types.
#' @param trim_ws Whitespace trimming.
#' @return The raw tibble.
#' @noRd
.read_sheet_data <- function(ss_input, sheet_name, na_strings, col_types, trim_ws) {
  googlesheets4::read_sheet(
    ss = ss_input,
    sheet = sheet_name,
    na = na_strings,
    col_types = col_types,
    trim_ws = trim_ws,
    .name_repair = "minimal"
  )
}


#' Perform post-read checks
#'
#' This helper validates the fetched data, specifically checking for empty results
#' to warn the user about potentially incorrect sheet names or empty tabs.
#'
#' @param sheet_data The fetched tibble.
#' @param sheet_name Name for messaging.
#' @param doc_id_for_msg ID for messaging.
#' @return The verified sheet data.
#' @noRd
.check_read_result <- function(sheet_data, sheet_name, doc_id_for_msg) {
  if (nrow(sheet_data) == 0) {
    cli::cli_warn(
      "Sheet {.val {sheet_name}} in document (ID: {.val {doc_id_for_msg}}) has no data (0 rows)."
    )
  }
  return(sheet_data)
}
