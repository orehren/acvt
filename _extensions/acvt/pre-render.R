# _pre_render.R
# Entry point for Quarto.
# Strategy:
# 1. Prefer installed R package 'acvt' (fast, robust).
# 2. Fallback to local scripts in 'R/' folder (standalone/portable).

# --- Helper Function: Bootstrap Local Environment ---
.bootstrap_standalone_env <- function() {
  # 1. Locate the 'R' directory relative to this script
  # sys.frame(1)$ofile returns the path to the currently sourced script.
  # We use a fallback for interactive execution or weird contexts.
  script_path <- sys.frame(1)$ofile

  if (is.null(script_path)) {
    extension_root <- "_extensions/orehren/acvt"
  } else {
    extension_root <- dirname(script_path)
  }

  r_dir <- file.path(extension_root, "R")

  if (!dir.exists(r_dir)) {
    stop("Critical Error: 'acvt' package missing AND local 'R' folder not found at: ", r_dir)
  }

  # 2. Create a clean environment
  # We load all functions into this sandbox to avoid polluting the global namespace.
  env <- new.env()

  # 3. Load ALL scripts from the R directory
  r_files <- list.files(r_dir, pattern = "\\.[Rr]$", full.names = TRUE)

  for (file in r_files) {
    source(file, local = env)
  }

  return(env)
}


# --- Main Execution Logic ---

if (requireNamespace("acvt", quietly = TRUE)) {
  # --- MODE A: PACKAGE INSTALLED ---
  tryCatch({
    acvt::fetch_cv_data()
  }, error = function(e) {
    message("Error in acvt::fetch_cv_data: ", e$message)
    quit(status = 1)
  })

} else {
  # --- MODE B: STANDALONE ---
  # Bootstrap the environment from local files
  script_env <- .bootstrap_standalone_env()

  # Execute Entry Point
  if (exists("fetch_cv_data", envir = script_env)) {
    script_env$fetch_cv_data()
  } else {
    stop("Error: Local scripts loaded, but entry point 'fetch_cv_data' not found.")
  }
}
