# _fetch_cv_data.R
# ==============================================================================
# Quarto Pre-render Script
# ------------------------------------------------------------------------------
# 1. Authentifiziert sich mit Google (Drive & Sheets).
# 2. Lädt CV-Daten basierend auf der YAML-Konfiguration der .qmd Datei.
# 3. Transformiert Dataframes in Zeilen-Listen (für sauberen YAML-Output).
# 4. Cached die Daten lokal (.cv_cache.rds) für schnelleres Re-Rendering.
# 5. Schreibt _cv_data.yml für den Zugriff durch Quarto/Lua.
# ==============================================================================

# --- Dependencies prüfen ---
required_pkgs <- c("yaml", "rmarkdown", "cli", "googledrive", "googlesheets4", "purrr", "checkmate", "rlang", "janitor")
missing_pkgs <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  stop(paste("Fehlende Pakete:", paste(missing_pkgs, collapse = ", ")))
}

main <- function() {
  # ----------------------------------------------------------------------------
  # 1. Setup & Pfade
  # ----------------------------------------------------------------------------
  cli::cli_h1("CV Data Extension Setup")

  # Wir suchen den Ordner 'R' innerhalb der Extension, um die Helper zu laden.
  # Wir suchen nach 'load_cv_sheets.R' als Anker.
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
    # Fallback für Development (wenn man im Root des Repos arbeitet)
    script_dir <- "R"
  } else {
    cli::cli_abort("Konnte den Ordner 'R' mit den Helper-Skripten nicht finden.")
  }

  # Alle .R Skripte im gefundenen Ordner sourcen (außer diesem Script selbst)
  helpers <- list.files(script_dir, pattern = "\\.[Rr]$", full.names = TRUE)
  helpers <- helpers[!grepl("_fetch_cv_data\\.R$", helpers)]

  for (h in helpers) {
    source(h, local = TRUE)
  }

  # ----------------------------------------------------------------------------
  # 2. Konfiguration lesen
  # ----------------------------------------------------------------------------
  # Wir scannen .qmd Dateien nach dem 'google-document' Key
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
    cli::cli_alert_warning("Keine 'google-document' Konfiguration gefunden. Überspringe.")
    return(invisible(NULL))
  }

  # ----------------------------------------------------------------------------
  # 3. Caching Logik
  # ----------------------------------------------------------------------------
  cache_file <- ".cv_cache.rds"
  output_yaml_file <- "_cv_data.yml"

  final_cv_data <- NULL
  is_cached <- FALSE

  # Cache ist valide für 24 Stunden
  if (file.exists(cache_file)) {
    age <- difftime(Sys.time(), file.info(cache_file)$mtime, units = "hours")
    if (age < 24) is_cached <- TRUE
  }

  # ----------------------------------------------------------------------------
  # 4. Daten laden (Cache oder Neu)
  # ----------------------------------------------------------------------------

  if (is_cached) {
    cli::cli_alert_success("Lade transformierte Daten aus Cache.")
    final_cv_data <- readRDS(cache_file)
  } else {
    # --- LIVE FETCH ---

    doc_identifier <- cv_config[["document-identifier"]]
    sheets_config <- cv_config[["sheets-to-load"]]
    auth_email <- cv_config[["auth-email"]]

    if (is.null(doc_identifier) || is.null(sheets_config)) {
      cli::cli_abort("Fehlende Konfiguration: document-identifier oder sheets-to-load.")
    }

    # Auth: Drive zuerst (Master), dann Token an Sheets übergeben
    cli::cli_process_start("Authentifiziere mit Google")
    tryCatch(
      {
        googledrive::drive_auth(email = auth_email %||% TRUE)
        googlesheets4::gs4_auth(token = googledrive::drive_token())
        cli::cli_process_done()
      },
      error = function(e) {
        cli::cli_process_failed()
        cli::cli_abort(c(
          "Authentifizierung fehlgeschlagen.",
          "i" = "Bitte führe einmalig `googledrive::drive_auth()` interaktiv aus.",
          "x" = e$message
        ))
      }
    )

    # Config Normalisierung für load_cv_sheets Helper
    final_sheets_config <- list()
    for (item in sheets_config) {
      if (is.list(item)) {
        final_sheets_config[[item$name]] <- item$shortname
      } else {
        final_sheets_config[[item]] <- gsub("[^a-z0-9_]", "_", tolower(item))
      }
    }

    # Daten laden (Ergebnis sind Tibbles/Dataframes)
    cli::cli_alert_info("Lade Sheets von Google...")

    # ID auflösen falls nötig (via Drive)
    real_doc_id <- doc_identifier
    if (!grepl("^[a-zA-Z0-9_-]{30,}$", doc_identifier)) {
      cli::cli_alert_info("Löse Namen '{doc_identifier}' auf...")
      drive_res <- googledrive::drive_get(doc_identifier)
      if (nrow(drive_res) == 0) cli::cli_abort("Sheet '{doc_identifier}' nicht gefunden.")
      real_doc_id <- drive_res$id[1]
    }

    raw_data_list <- load_cv_sheets(
      doc_identifier = real_doc_id,
      sheets_to_load = final_sheets_config
    )

    # --- TRANSFORMATION ---
    cli::cli_alert_info("Transformiere Daten für sequentiellen YAML Export...")

    final_cv_data <- purrr::map(raw_data_list, function(sheet_content) {
      if (is.data.frame(sheet_content)) {
        # 1. Transponieren: Dataframe -> Liste von benannten Zeilen
        rows <- purrr::transpose(sheet_content)

        # 2. WICHTIG: Benannte Zeile -> Liste von Key-Value Paaren
        # Wir wandeln `list(a=1, b=2)` um in `list(list(key="a", val=1), list(key="b", val=2))`
        # Damit erzwingen wir, dass YAML eine Liste schreibt und Lua die Reihenfolge behält.

        list_of_ordered_rows <- purrr::map(rows, function(row) {
          # Wir iterieren über die Namen und Werte und bauen eine unbenannte Liste
          purrr::imap(row, function(val, key) {
            list(key = key, value = val)
          }) |> unname()
        })

        return(list_of_ordered_rows)
      }
      return(sheet_content)
    })

    # Cache speichern
    saveRDS(final_cv_data, cache_file)
  }

  # --- YAML EXPORT ---
  yaml::write_yaml(list(cv_data = final_cv_data), output_yaml_file)
  cli::cli_alert_success("Daten bereitgestellt in {.file {output_yaml_file}}")
}

main()
