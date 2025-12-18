#' Create a new Academic-CV Project
#'
#' Implements the logic for the RStudio Project Wizard.
#' Accepts dynamic arguments via ellipsis.
#' Adds a temporary self-destructing hook to open the main file on first launch.
#'
#' @param path The path to the new project.
#' @param ... Dynamic arguments passed by RStudio based on the .dcf file.
#' @export
acvt_template <- function(path, ...) {
  # 1. Capture Arguments
  dots <- list(...)
  firstname <- dots$firstname
  lastname <- dots$lastname
  renv_enabled <- isTRUE(dots$renv)
  git_enabled <- isTRUE(dots$git)

  # 2. Create Project Directory
  path <- normalizePath(path, mustWork = FALSE)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  # 3. Locate Skeleton
  skeleton_dir <- system.file("rstudio/templates/project/skeleton", package = "acvt")
  if (!nzchar(skeleton_dir)) {
    stop("Could not find the project template skeleton in the 'acvt' package.")
  }

  # 4. Copy Extension Files
  source_ext_dir <- file.path(skeleton_dir, "_extensions")
  dest_ext_dir <- file.path(path, "_extensions/orehren")

  if (!dir.exists(dest_ext_dir)) dir.create(dest_ext_dir, recursive = TRUE)
  file.copy(from = source_ext_dir, to = path, recursive = TRUE)

  # 5. Move Template Files to Root & Rename
  source_of_truth_dir <- file.path(dest_ext_dir, "acvt")

  file.copy(
    from = file.path(source_of_truth_dir, "_quarto.yml"),
    to = file.path(path, "_quarto.yml")
  )

  target_qmd <- file.path(path, "cv.qmd")
  file.copy(
    from = file.path(source_of_truth_dir, "Academic-CV-template.qmd"),
    to = target_qmd
  )

  # 6. Personalize YAML Header
  .update_template_yaml(target_qmd, firstname, lastname)

  # 7. Initialize Version Control & Environment
  if (git_enabled && nzchar(Sys.which("git"))) {
    system(paste("git -C", shQuote(path), "init"), ignore.stdout = TRUE, ignore.stderr = TRUE)
  }

  if (renv_enabled && requireNamespace("renv", quietly = TRUE)) {
    renv::init(project = path, bare = TRUE, restart = FALSE)
  }

  # 8. Inject Temporary Self-Destructing Hook
  .add_temporary_open_hook(path, "cv.qmd")

  return(invisible(TRUE))
}


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Update Template YAML Header
#'
#' Modifies the author details in the generated Quarto markdown file.
#'
#' @details
#' This function uses Regular Expressions instead of a YAML parser to modify
#' the file. This approach is chosen for two reasons:
#' 1. **Robustness:** It prevents parsing errors if the Quarto YAML header contains
#'    complex structures or tab characters that might crash standard R YAML parsers.
#' 2. **Preservation:** It ensures that comments and specific indentation styles
#'    in the rest of the file remain untouched.
#'
#' @param file_path The absolute path to the `.qmd` file to be modified.
#' @param firstname The user's first name to inject.
#' @param lastname The user's last name to inject.
#'
#' @return NULL. The function is used for its side effect of writing to the file.
#' @noRd
.update_template_yaml <- function(file_path, firstname, lastname) {
  lines <- readLines(file_path)

  if (!is.null(firstname) && nzchar(firstname)) {
    lines <- gsub("^(\\s*firstname:\\s*).*", paste0("\\1\"", firstname, "\""), lines)
  }

  if (!is.null(lastname) && nzchar(lastname)) {
    lines <- gsub("^(\\s*lastname:\\s*).*", paste0("\\1\"", lastname, "\""), lines)
  }

  writeLines(lines, file_path)
}

#' Inject Self-Destructing File Open Hook
#'
#' Appends a temporary hook to the project's `.Rprofile` to ensure the main
#' document opens automatically upon the first project launch.
#'
#' @details
#' RStudio's native `OpenFiles` directive in `.dcf` templates is susceptible to
#' race conditions, often failing to open the file if the filesystem or context
#' switch is too slow.
#'
#' This function solves this by injecting code that runs on `rstudio.sessionInit`.
#' To keep the user's project clean, the injected code contains a "Self-Destruct"
#' mechanism: it reads the `.Rprofile`, removes its own code block, and saves
#' the file immediately after opening the target document.
#'
#' @param path The root directory of the new project.
#' @param filename The name of the file to open (e.g., "cv.qmd").
#'
#' @return NULL. The function is used for its side effect of modifying `.Rprofile`.
#' @noRd
.add_temporary_open_hook <- function(path, filename) {
  rprofile_path <- file.path(path, ".Rprofile")

  # Unique markers to identify the block for deletion
  marker_start <- "# <<< ACVT TEMPORARY HOOK START >>>"
  marker_end <- "# <<< ACVT TEMPORARY HOOK END >>>"

  # The code injected into the new project's .Rprofile
  hook_code <- c(
    "",
    marker_start,
    "local({",
    "  if (interactive() && Sys.getenv('RSTUDIO') == '1') {",
    "    setHook('rstudio.sessionInit', function(newSession) {",
    sprintf("      if (newSession && file.exists('%s') && requireNamespace('rstudioapi', quietly = TRUE)) {", filename),
    sprintf("        rstudioapi::navigateToFile('%s')", filename),
    "        ",
    "        # --- SELF DESTRUCT SEQUENCE ---",
    "        # Reads .Rprofile, removes this block, and saves.",
    "        try({",
    "          p <- '.Rprofile'",
    "          if (file.exists(p)) {",
    "            l <- readLines(p)",
    sprintf("            s <- which(l == '%s')", marker_start),
    sprintf("            e <- which(l == '%s')", marker_end),
    "            if (length(s) > 0 && length(e) > 0) {",
    "              l <- l[-(s:e)]", # Remove lines between markers (inclusive)
    "              writeLines(l, p)",
    "            }",
    "          }",
    "        }, silent = TRUE)",
    "      }",
    "    }, action = 'append')",
    "  }",
    "})",
    marker_end
  )

  # Append to .Rprofile (create if not exists)
  write(paste(hook_code, collapse = "\n"), file = rprofile_path, append = TRUE)
}
