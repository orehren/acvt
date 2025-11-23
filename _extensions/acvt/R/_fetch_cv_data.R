# _fetch_cv_data.R
# This script orchestrates the data fetching process from Google Sheets to YAML.
# It acts as a pre-render hook to ensure data is available before Quarto processing.

# Ensure all necessary packages are available to prevent runtime errors during the pre-render phase.
required_pkgs <- c("yaml", "rmarkdown", "cli", "googledrive", "googlesheets4", "purrr", "checkmate", "rlang", "janitor")
missing_pkgs <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  stop(paste("Missing packages:", paste(missing_pkgs, collapse = ", ")))
}

main <- function() {
  cli::cli_h1("CV Data Extension Setup")

  # Locate the helper scripts dynamically to support both development (repo root) and production (extension folder) environments.
  ext_r_files <- list.files(
    path = "_extensions",
    pattern = "^load_cv_sheets\\.R$",
    recursive = TRUE,
    full.names = TRUE
  )

  script_dir <- NULL
  if (length(ext_r_files) > 0) {
    script_dir <- dirname(ext_r_files[1])
  } else if (file.exists("R/load_cv_sheets.R")) {
    script_dir <- "R"
  } else {
    cli::cli_abort("Could not find the 'R' folder containing helper scripts.")
  }

  # Load all helper functions from the identified directory to make them available for the fetching process.
  helpers <- list.files(script_dir, pattern = "\\.[Rr]$", full.names = TRUE)
  helpers <- helpers[!grepl("_fetch_cv_data\\.R$", helpers)]

  for (h in helpers) {
    source(h, local = TRUE)
  }

  # Identify the relevant .qmd file and extract the Google Sheet configuration to know which data to fetch.
  qmd_files <- list.files(pattern = "\\.qmd$")
  cv_config <- NULL

  for (f in qmd_files) {
    fm <- rmarkdown::yaml_front_matter(f)
    if (!is.null(fm$`google-document`)) {
      cv_config <- fm$`google-document`
      break
    }
  }

  if (is.null(cv_config)) {
    cli::cli_alert_warning("No 'google-document' configuration found. Skipping.")
    return(invisible(NULL))
  }

  cache_file <- ".cv_cache.rds"
  output_yaml_file <- "_cv_data.yml"

  final_cv_data <- NULL
  is_cached <- FALSE

  # Check for a valid cache file to avoid unnecessary API calls and speed up the rendering process.
  if (file.exists(cache_file)) {
    age <- difftime(Sys.time(), file.info(cache_file)$mtime, units = "hours")
    if (age < 24) is_cached <- TRUE
  }

  if (is_cached) {
    cli::cli_alert_success("Loading transformed data from cache.")
    final_cv_data <- readRDS(cache_file)
  } else {

    doc_identifier <- cv_config[["document-identifier"]]
    sheets_config <- cv_config[["sheets-to-load"]]
    auth_email <- cv_config[["auth-email"]]

    if (is.null(doc_identifier) || is.null(sheets_config)) {
      cli::cli_abort("Missing configuration: document-identifier or sheets-to-load.")
    }

    # Authenticate with Google services to enable access to private sheets.
    cli::cli_process_start("Authenticating with Google")
    tryCatch(
      {
        googledrive::drive_auth(email = auth_email %||% TRUE)
        googlesheets4::gs4_auth(token = googledrive::drive_token())
        cli::cli_process_done()
      },
      error = function(e) {
        cli::cli_process_failed()
        cli::cli_abort(c(
          "Authentication failed.",
          "i" = "Please run `googledrive::drive_auth()` interactively once.",
          "x" = e$message
        ))
      }
    )

    # Normalize the sheet configuration to ensure a consistent format for the loading function.
    final_sheets_config <- list()
    for (item in sheets_config) {
      if (is.list(item)) {
        final_sheets_config[[item$name]] <- item$shortname
      } else {
        final_sheets_config[[item]] <- gsub("[^a-z0-9_]", "_", tolower(item))
      }
    }

    cli::cli_alert_info("Loading Sheets from Google...")

    # Resolve the document ID if a name was provided to ensure the correct file is accessed.
    real_doc_id <- doc_identifier
    if (!grepl("^[a-zA-Z0-9_-]{30,}$", doc_identifier)) {
      cli::cli_alert_info("Resolving name '{doc_identifier}'...")
      drive_res <- googledrive::drive_get(doc_identifier)
      if (nrow(drive_res) == 0) cli::cli_abort("Sheet '{doc_identifier}' not found.")
      real_doc_id <- drive_res$id[1]
    }

    raw_data_list <- load_cv_sheets(
      doc_identifier = real_doc_id,
      sheets_to_load = final_sheets_config
    )

    cli::cli_alert_info("Transforming data for sequential YAML export...")

    # Transform the loaded dataframes into a specific list structure.
    # This transformation is necessary to preserve the column order when exporting to YAML and subsequently processing with Lua.
    final_cv_data <- purrr::map(raw_data_list, function(sheet_content) {
      if (is.data.frame(sheet_content)) {
        rows <- purrr::transpose(sheet_content)

        list_of_ordered_rows <- purrr::map(rows, function(row) {
          purrr::imap(row, function(val, key) {
            list(key = key, value = val)
          }) |> unname()
        })

        return(list_of_ordered_rows)
      }
      return(sheet_content)
    })

    saveRDS(final_cv_data, cache_file)
  }

  # Export the processed data to a YAML file for the Quarto extension to consume.
  yaml::write_yaml(list(cv_data = final_cv_data), output_yaml_file)
  cli::cli_alert_success("Data ready in {.file {output_yaml_file}}")
}

main()
