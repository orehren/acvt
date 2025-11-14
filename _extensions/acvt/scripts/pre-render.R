#!/usr/bin/env Rscript

# --- 0. Setup Debug Logging ---------------------------------------------------
# All output from this script (messages, warnings, errors) will be redirected
# to this log file. This provides a clear trace of the script's execution.
log_file <- "pre-render-debug.log"
sink(log_file, type = "output", split = TRUE)
sink(log_file, type = "message")

# Ensure that the sink is always closed, even if the script fails.
on.exit({
  message("INFO: Closing log file.")
  sink(type = "message")
  sink(type = "output")
}, add = TRUE)

message("INFO: Pre-render script started at ", Sys.time())

# --- 1. Load Required Libraries -----------------------------------------------
# This script is self-contained and only relies on widely used packages.
library(jsonlite)
library(googlesheets4)
library(yaml)

# --- 2. Read and Parse Quarto Metadata ----------------------------------------
message("INFO: Reading metadata from QUARTO_INPUT_FILE_METADATA...")
metadata_json <- Sys.getenv("QUARTO_INPUT_FILE_METADATA")

if (identical(metadata_json, "")) {
  message("WARN: QUARTO_INPUT_FILE_METADATA is empty. Script will now exit.")
  quit()
}
message("INFO: Metadata JSON received:\n", metadata_json)
metadata <- fromJSON(metadata_json)

# Check if the required configuration exists.
if (is.null(metadata) || is.null(metadata$`google-document`)) {
  message("WARN: `google-document` key not found in YAML. Skipping data fetch.")
  quit()
}

# --- 3. Extract and Validate Configuration ------------------------------------
message("INFO: Extracting and validating configuration...")
cv_config <- metadata$`google-document`
doc_id <- cv_config[["document-identifier"]]
sheets_config <- cv_config[["sheets-to-load"]]
auth_email <- cv_config[["auth-email"]] # Will be NULL if not present

if (is.null(doc_id)) {
  stop("ERROR: `document-identifier` is missing under the `google-document` key.", call. = FALSE)
}
if (is.null(sheets_config)) {
  stop("ERROR: `sheets-to-load` is missing under the `google-document` key.", call. = FALSE)
}
message("INFO: Configuration validated successfully.")
message("INFO: Document Identifier: ", doc_id)

# --- 4. Handle Authentication -------------------------------------------------
message("INFO: Authenticating with Google...")
tryCatch({
  gs4_auth(email = auth_email %||% TRUE, cache = TRUE, use_oob = TRUE)
  message("INFO: Authentication successful.")
}, error = function(e) {
  message("ERROR: Google authentication failed. Please ensure you have a cached token.")
  stop(e)
})

# --- 5. Process Sheet Configuration -------------------------------------------
message("INFO: Processing sheet configuration...")
sheets_to_load <- list()
for (item in sheets_config) {
  if (is.list(item)) {
    sheet_name <- item$name
    target_name <- item$shortname
    sheets_to_load[[sheet_name]] <- target_name
  } else {
    sheet_name <- item
    target_name <- gsub("[^[:alnum:]_]+", "_", tolower(sheet_name))
    sheets_to_load[[sheet_name]] <- target_name
  }
}
message("INFO: Sheets to load have been processed.")
print(sheets_to_load)

# --- 6. Load Data from Google Sheet -------------------------------------------
message("INFO: Loading data from Google Sheet: ", doc_id)
loaded_data <- list()

for (sheet_name in names(sheets_to_load)) {
  target_name <- sheets_to_load[[sheet_name]]
  message("INFO: Reading sheet '", sheet_name, "' into '", target_name, "'...")

  tryCatch({
    sheet_data <- read_sheet(ss = doc_id, sheet = sheet_name, col_types = "c")
    # Check if the returned data is empty or NULL, which can happen.
    if (is.null(sheet_data) || nrow(sheet_data) == 0) {
        stop(paste("Sheet '", sheet_name, "' was found but returned no data."), call. = FALSE)
    }
    loaded_data[[target_name]] <- sheet_data
    message("INFO: Successfully read sheet '", sheet_name, "'.")
  }, error = function(e) {
    # Make failure to read a sheet a fatal error.
    message("ERROR: Failed to read sheet '", sheet_name, "'. Please check sheet name and permissions.")
    stop(e)
  })
}
message("INFO: Data loading complete.")
message("INFO: Structure of loaded_data:")
utils::str(loaded_data)

# --- 7. Generate and Output YAML ----------------------------------------------
message("INFO: Generating final YAML to be passed to Quarto...")
output_list <- list(cv_data = loaded_data)
output_yaml <- as.yaml(output_list, indent.mapping.sequence = TRUE)

message("INFO: Final YAML output:\n", output_yaml)
cat(output_yaml)

message("INFO: Pre-render script finished successfully.")
