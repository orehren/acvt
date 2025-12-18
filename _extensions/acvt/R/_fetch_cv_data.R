#' Fetch CV Data from Google Sheets or Local Files
#'
#' Orchestrates the extraction, transformation, and loading (ETL) of CV data.
#' It reads the configuration from the QMD file, checks the cache, fetches data
#' from configured sources (Google Sheets, Excel, CSV, JSON), and saves the
#' result to `.cv_data.json`.
#'
#' @return Invisible NULL. Side effect: Creates or updates `.cv_data.json`.
#' @export
fetch_cv_data <- function() {
  # Ensure runtime dependencies are available
  .ensure_dependencies(c("cli", "jsonlite", "purrr", "rlang", "tools", "readxl"))

  cli::cli_h1("CV Data Extension Pipeline")

  config <- .get_quarto_config()
  if (is.null(config)) {
    return(invisible(NULL))
  }

  # Caching Logic: Check if we can skip the fetch
  if (.evaluate_cache_state(".cv_data.json", config)) {
    return(invisible(NULL))
  }

  sheets_map <- .normalize_sheet_config(config[["sheets-to-load"]])
  sources <- .resolve_sources(config[["document-identifier"]])

  # Pass auth_email explicitly
  raw_data <- .fetch_all_sources(sources, sheets_map, config[["auth-email"]])

  if (length(raw_data) == 0) {
    cli::cli_alert_warning("No data found in any source.")
    return(invisible(NULL))
  }

  cli::cli_h2("Aggregating & Transforming")

  master_data <- purrr::reduce(raw_data, .merge_source_lists)
  lua_ready_data <- .transform_data_for_lua(master_data)

  .write_json_cache(lua_ready_data, ".cv_data.json")
}


# ==============================================================================
# 1. SETUP & CONFIGURATION
# ==============================================================================

#' Ensure Required Packages are Available
#'
#' @param pkgs Character vector of package names.
#' @return NULL. Stops execution if packages are missing.
.ensure_dependencies <- function(pkgs) {
  missing <- pkgs[!purrr::map_lgl(pkgs, requireNamespace, quietly = TRUE)]
  if (length(missing) > 0) {
    stop(paste("Missing required packages:", paste(missing, collapse = ", ")))
  }
}

#' Retrieve Configuration from QMD Frontmatter
#'
#' @return A list containing the configuration or NULL if not found.
.get_quarto_config <- function() {
  qmd_files <- list.files(pattern = "\\.qmd$")
  configs <- purrr::map(qmd_files, ~ rmarkdown::yaml_front_matter(.x)$`google-document`)
  valid_configs <- purrr::compact(configs)

  if (length(valid_configs) == 0) {
    cli::cli_alert_warning("No 'google-document' configuration found.")
    return(NULL)
  }
  return(valid_configs[[1]])
}

#' Helper to safely retrieve config values with defaults
#'
#' @param config List object.
#' @param key String key.
#' @param default Fallback value.
#' @return The value or the default.
.get_conf_val <- function(config, key, default) {
  val <- config[[key]]
  if (is.null(val)) {
    return(default)
  }
  return(val)
}

#' Evaluate Cache Status
#'
#' Determines whether to skip the data fetch based on file existence,
#' user configuration, and file age.
#'
#' @param path Path to the cache file.
#' @param config The parsed YAML configuration list.
#' @return Logical TRUE if fetch should be skipped (cache is valid), FALSE otherwise.
.evaluate_cache_state <- function(path, config) {
  # 1. Hard Requirement: File must exist
  if (!file.exists(path)) {
    return(FALSE)
  }

  # 2. Check if caching is explicitly disabled
  use_cache <- .get_conf_val(config, "sheet-cache", TRUE)
  if (isFALSE(use_cache)) {
    cli::cli_alert_info("Caching disabled by config. Forcing update.")
    return(FALSE)
  }

  # 3. Check if updates are disabled (Frozen Cache)
  allow_update <- .get_conf_val(config, "cache-update", TRUE)
  if (isFALSE(allow_update)) {
    cli::cli_alert_success("Cache update disabled. Using existing data from {.file {path}}.")
    return(TRUE)
  }

  # 4. Check Age against Interval
  age_hours <- difftime(Sys.time(), file.info(path)$mtime, units = "hours")
  max_age <- as.numeric(.get_conf_val(config, "cache-update-interval", 24))

  if (age_hours < max_age) {
    cli::cli_alert_success("Cached data found in {.file {path}} (fresh). Skipping fetch.")
    return(TRUE)
  }

  # Cache is stale
  cli::cli_alert_info("Cache is older than {max_age} hours. Refreshing data...")
  return(FALSE)
}

#' Normalize Sheet Configuration
#'
#' @param raw_config List from YAML.
#' @return A named list: names = Real Sheet Names, values = Short Names.
.normalize_sheet_config <- function(raw_config) {
  purrr::map(raw_config, function(item) {
    if (is.list(item)) {
      return(stats::setNames(item$shortname, item$name))
    }
    stats::setNames(gsub("[^a-z0-9_]", "_", tolower(item)), item)
  }) |> unlist()
}


# ==============================================================================
# 2. SOURCE DISCOVERY
# ==============================================================================

#' Resolve Source Identifiers to Source Objects
#'
#' @param raw_ids List or vector of identifiers.
#' @return A list of lists, each containing `path` and `type`.
.resolve_sources <- function(raw_ids) {
  if (is.null(raw_ids)) cli::cli_abort("Missing 'document-identifier'.")

  purrr::map(as.list(raw_ids), .expand_path_to_sources) |>
    purrr::list_flatten()
}

#' Expand Single Path to Source Objects
#'
#' @param path String path or ID.
#' @return List of source objects.
.expand_path_to_sources <- function(path) {
  if (dir.exists(path)) {
    files <- list.files(path, full.names = TRUE)
    return(purrr::map(files, .classify_source))
  }
  list(.classify_source(path))
}

#' Classify Source Type based on File Extension
#'
#' @param path File path or Google ID.
#' @return List with `path` and `type`.
.classify_source <- function(path) {
  if (!file.exists(path)) {
    return(list(path = path, type = "google"))
  }

  ext <- tolower(tools::file_ext(path))
  type <- switch(ext,
    "xlsx" = "local_xlsx",
    "xls"  = "local_xlsx",
    "csv"  = "local_csv",
    "json" = "local_json",
    "unknown"
  )
  list(path = path, type = type)
}


# ==============================================================================
# 3. DATA EXTRACTION (READER FACTORY)
# ==============================================================================

#' Fetch Data from All Sources
#'
#' @param sources List of source objects.
#' @param sheets_map Named list of sheet mappings.
#' @param auth_email Email for Google Auth.
#' @return List of data lists (one per source).
.fetch_all_sources <- function(sources, sheets_map, auth_email) {
  purrr::map(sources, function(src) {
    cli::cli_h2(paste("Processing:", src$type))

    tryCatch(
      .read_source(src, sheets_map, auth_email),
      error = function(e) {
        cli::cli_alert_danger("Failed to load {.val {src$path}}: {e$message}")
        list()
      }
    )
  }) |> purrr::compact()
}

#' Dispatcher for Source Reading
#'
#' @param source Source object.
#' @param sheets_map Config map.
#' @param auth_email Email string.
#' @return Named list of DataFrames.
.read_source <- function(source, sheets_map, auth_email) {
  switch(source$type,
    "google" = .read_google(source$path, sheets_map, auth_email),
    "local_xlsx" = .read_xls(source$path, sheets_map),
    "local_csv" = .read_flat(source$path, "csv", sheets_map),
    "local_json" = .read_flat(source$path, "json", sheets_map),
    {
      cli::cli_alert_warning("Skipping unknown source: {source$path}")
      list()
    }
  )
}

#' Read Google Sheet
#'
#' Delegates loading to the helper script.
#'
#' @param id Google Sheet ID or Name.
#' @param sheets_map Config map.
#' @param email Auth email.
#' @return Named list of DataFrames.
.read_google <- function(id, sheets_map, email) {
  # Check if helper function is available (Package or Sourced)
  if (!exists("load_cv_sheets", mode = "function")) {
    stop("Function 'load_cv_sheets' not found. Ensure package is loaded or scripts are sourced.")
  }

  if (!googlesheets4::gs4_has_token()) {
    cli::cli_alert_info("Authenticating Google...")
    googledrive::drive_auth(email = email %||% TRUE)
    googlesheets4::gs4_auth(token = googledrive::drive_token())
  }

  cli::cli_alert_info("Fetching Google Sheet: {.val {id}}")

  # Direct call to the helper function
  load_cv_sheets(id, as.list(sheets_map))
}

#' Read Local Excel File
#'
#' @param path File path.
#' @param sheets_map Config map.
#' @return Named list of DataFrames (Keys = Short Names).
.read_xls <- function(path, sheets_map) {
  cli::cli_alert_info("Reading Excel: {.file {path}}")
  available <- readxl::excel_sheets(path)

  data_list <- list()

  purrr::iwalk(sheets_map, function(short_name, target_name) {
    match <- .find_fuzzy_match(target_name, available)

    if (!is.null(match)) {
      cli::cli_alert_info("  -> Found sheet {.val {match}} as {.val {short_name}}")
      data_list[[short_name]] <<- as.data.frame(readxl::read_excel(path, sheet = match))
    }
  })

  return(data_list)
}

#' Read Flat Files (CSV/JSON)
#'
#' @param path File path.
#' @param type "csv" or "json".
#' @param sheets_map Config map.
#' @return Named list of DataFrames (Keys = Short Names).
.read_flat <- function(path, type, sheets_map) {
  fname <- tools::file_path_sans_ext(basename(path))
  match <- .find_fuzzy_match(fname, names(sheets_map))

  if (is.null(match)) {
    return(list())
  }

  short_name <- sheets_map[[match]]
  cli::cli_alert_info("Reading {.val {type}}: {.file {path}} as {.val {short_name}}")

  df <- if (type == "csv") {
    read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  } else {
    jsonlite::fromJSON(path, flatten = TRUE)
  }

  if (is.list(df) && !is.data.frame(df)) df <- as.data.frame(df)

  stats::setNames(list(df), short_name)
}

#' Fuzzy Match String in Candidates
#'
#' @param target String to find.
#' @param candidates Vector of strings to search in.
#' @return Matching string from candidates or NULL.
.find_fuzzy_match <- function(target, candidates) {
  if (target %in% candidates) {
    return(target)
  }

  norm_t <- tolower(trimws(target))
  norm_c <- tolower(trimws(candidates))

  idx <- match(norm_t, norm_c)
  if (!is.na(idx)) {
    return(candidates[idx])
  }

  slugify <- function(x) tolower(gsub("[^[:alnum:]]", "", x))
  idx <- match(slugify(target), slugify(candidates))
  if (!is.na(idx)) {
    return(candidates[idx])
  }

  return(NULL)
}


# ==============================================================================
# 4. AGGREGATION & TRANSFORMATION
# ==============================================================================

#' Merge Two Data Lists
#'
#' @param existing_list Accumulator list.
#' @param new_list New list to merge in.
#' @return Merged list.
.merge_source_lists <- function(existing_list, new_list) {
  purrr::iwalk(new_list, function(df, sheet_name) {
    if (!is.data.frame(df)) {
      return()
    }

    if (hasName(existing_list, sheet_name)) {
      existing_list[[sheet_name]] <<- .robust_bind_rows(existing_list[[sheet_name]], df)
    } else {
      existing_list[[sheet_name]] <<- df
    }
  })
  return(existing_list)
}

#' Robust Row Binding
#'
#' @param df1 DataFrame 1.
#' @param df2 DataFrame 2.
#' @return Combined DataFrame.
.robust_bind_rows <- function(df1, df2) {
  all_cols <- union(names(df1), names(df2))

  standardize <- function(df, cols) {
    missing <- setdiff(cols, names(df))
    df[missing] <- NA
    df[, cols, drop = FALSE]
  }

  rbind(standardize(df1, all_cols), standardize(df2, all_cols))
}

#' Transform Data for Lua Consumption
#'
#' @param data_list Named list of DataFrames.
#' @return List structure matching Lua expectations.
.transform_data_for_lua <- function(data_list) {
  purrr::map(data_list, function(df) {
    if (!is.data.frame(df)) {
      return(df)
    }

    # Ensure all data is character type for safe Lua/JSON handling
    df[] <- lapply(df, as.character)

    purrr::transpose(df) |>
      purrr::map(function(row) {
        purrr::imap(row, ~ list(key = .y, value = .x)) |> unname()
      })
  })
}

#' Write JSON Cache
#'
#' @param data Data to save.
#' @param path File path.
#' @return NULL
.write_json_cache <- function(data, path) {
  output <- list(cv_data = data)
  jsonlite::write_json(output, path, auto_unbox = TRUE, pretty = FALSE)
  cli::cli_alert_success("Data successfully updated in {.file {path}}")
}
