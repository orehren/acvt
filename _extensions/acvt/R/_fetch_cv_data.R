#' Main Entry Point for CV Data Pipeline
#'
#' Orchestrates the extraction, transformation, and loading (ETL) of CV data.
#' Uses a dedicated environment for helper scripts to maintain clean scoping.
#'
#' @return Invisible NULL. Side effect: Creates or updates `.cv_data.json`.
main <- function() {
  .ensure_dependencies(c("cli", "jsonlite", "purrr", "rlang", "tools", "readxl"))

  cli::cli_h1("CV Data Extension Pipeline")

  # Dependency Injection: Load helpers into a dedicated environment
  # to avoid polluting the global namespace.
  helpers_env <- .load_helper_scripts()

  config <- .get_quarto_config()
  if (is.null(config)) return(invisible(NULL))

  # Caching prevents expensive API calls during iterative rendering.
  if (.is_cache_fresh(".cv_data.json")) return(invisible(NULL))

  sheets_map <- .normalize_sheet_config(config[["sheets-to-load"]])
  sources    <- .resolve_sources(config[["document-identifier"]])

  raw_data <- .fetch_all_sources(sources, sheets_map, config[["auth-email"]], helpers_env)

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

#' Load External Helper Scripts into Isolated Environment
#'
#' @return An environment containing the loaded functions.
.load_helper_scripts <- function() {
  ext_files <- list.files("_extensions", pattern = "^load_cv_sheets\\.R$", recursive = TRUE, full.names = TRUE)

  script_dir <- "R"
  if (length(ext_files) > 0) script_dir <- dirname(ext_files[1])

  if (!dir.exists(script_dir)) cli::cli_abort("Helper script directory not found.")

  helpers <- list.files(script_dir, pattern = "\\.[Rr]$", full.names = TRUE)
  helpers <- helpers[!grepl("_fetch_cv_data\\.R$", helpers)]

  env <- new.env(parent = baseenv())
  purrr::walk(helpers, source, local = env)

  return(env)
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

#' Check Cache Freshness
#'
#' @param path Path to the cache file.
#' @param max_age_hours Maximum age in hours.
#' @return Logical TRUE if cache is valid.
.is_cache_fresh <- function(path, max_age_hours = 24) {
  if (!file.exists(path)) return(FALSE)

  age <- difftime(Sys.time(), file.info(path)$mtime, units = "hours")
  if (age < max_age_hours) {
    cli::cli_alert_success("Cached data found in {.file {path}} (fresh). Skipping fetch.")
    return(TRUE)
  }
  return(FALSE)
}

#' Normalize Sheet Configuration
#'
#' @param raw_config List from YAML.
#' @return A named list: names = Real Sheet Names, values = Short Names.
.normalize_sheet_config <- function(raw_config) {
  purrr::map(raw_config, function(item) {
    if (is.list(item)) return(stats::setNames(item$shortname, item$name))
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

  # Flattening is required because a directory path expands into multiple file paths.
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
#' @param helpers_env Environment containing helper functions.
#' @return List of data lists (one per source).
.fetch_all_sources <- function(sources, sheets_map, auth_email, helpers_env) {
  purrr::map(sources, function(src) {
    cli::cli_h2(paste("Processing:", src$type))

    # Isolation ensures that a single corrupt file doesn't crash the entire pipeline.
    tryCatch(
      .read_source(src, sheets_map, auth_email, helpers_env),
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
#' @param helpers_env Environment containing helper functions.
#' @return Named list of DataFrames.
.read_source <- function(source, sheets_map, auth_email, helpers_env) {
  switch(source$type,
         "google"     = .read_google(source$path, sheets_map, auth_email, helpers_env),
         "local_xlsx" = .read_excel(source$path, sheets_map),
         "local_csv"  = .read_flat(source$path, "csv", sheets_map),
         "local_json" = .read_flat(source$path, "json", sheets_map),
         {
           cli::cli_alert_warning("Skipping unknown source: {source$path}")
           list()
         }
  )
}

#' Read Google Sheet
#'
#' @param id Google Sheet ID or Name.
#' @param sheets_map Config map.
#' @param email Auth email.
#' @param helpers_env Environment containing helper functions.
#' @return Named list of DataFrames.
.read_google <- function(id, sheets_map, email, helpers_env) {
  if (is.null(helpers_env$load_cv_sheets)) {
    stop("Function 'load_cv_sheets' not found in helper environment.")
  }

  if (!googlesheets4::gs4_has_token()) {
    cli::cli_alert_info("Authenticating Google...")
    googledrive::drive_auth(email = email %||% TRUE)
    googlesheets4::gs4_auth(token = googledrive::drive_token())
  }

  cli::cli_alert_info("Fetching Google Sheet: {.val {id}}")

  # load_cv_sheets handles ID resolution and sheet filtering internally.
  helpers_env$load_cv_sheets(id, as.list(sheets_map))
}

#' Read Local Excel File
#'
#' @param path File path.
#' @param sheets_map Config map.
#' @return Named list of DataFrames (Keys = Short Names).
.read_excel <- function(path, sheets_map) {
  cli::cli_alert_info("Reading Excel: {.file {path}}")
  available <- readxl::excel_sheets(path)

  data_list <- list()

  # We use iwalk to explicitly assign data to the SHORT NAME key,
  # as map/imap would default to preserving the input names (Real Names).
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

  if (is.null(match)) return(list())

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
  if (target %in% candidates) return(target)

  norm_t <- tolower(trimws(target))
  norm_c <- tolower(trimws(candidates))

  idx <- match(norm_t, norm_c)
  if (!is.na(idx)) return(candidates[idx])

  slugify <- function(x) tolower(gsub("[^[:alnum:]]", "", x))
  idx <- match(slugify(target), slugify(candidates))
  if (!is.na(idx)) return(candidates[idx])

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
    if (!is.data.frame(df)) return()

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
    if (!is.data.frame(df)) return(df)

    # Lua/JSON serialization is safer with pure strings, avoiding
    # issues with Factors, Dates, or mixed types in the Lua filter.
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

# Execute
main()
