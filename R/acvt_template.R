#' Create a new Academic CV Project
#'
#' Implements the logic for the RStudio Project Wizard.
#' Accepts dynamic arguments via ellipsis to remain flexible regarding the .dcf configuration.
#'
#' @param path The path to the new project.
#' @param ... Dynamic arguments passed by RStudio based on the .dcf file (e.g. firstname, lastname, renv, git).
#' @export
acvt_template <- function(path, ...) {

  # 1. Capture and Extract Arguments
  dots <- list(...)

  firstname <- dots$firstname
  lastname  <- dots$lastname

  # Use isTRUE to handle potential NULLs safely
  # renv_enabled <- isTRUE(dots$renv)
  # git_enabled  <- isTRUE(dots$git)

  # 2. Create Project Directory
  # path <- normalizePath(path, mustWork = FALSE)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  # 3. Locate Skeleton
  skeleton_dir <- system.file("rstudio/templates/project/skeleton", package = "acvt")
  # if (!nzchar(skeleton_dir)) {
  #   stop("Could not find the project template skeleton in the 'acvt' package.")
  # }

  # 4. Copy Extension Files
  source_ext_dir <- file.path(skeleton_dir, "_extensions")
  dest_ext_dir   <- file.path(path, "_extensions")

  if (!dir.exists(dest_ext_dir)) dir.create(dest_ext_dir, recursive = TRUE)
  file.copy(from = source_ext_dir, to = path, recursive = TRUE)

  # 5. Move Template Files to Root & Rename
  source_of_truth_dir <- file.path(dest_ext_dir, "orehren", "acvt")
  qmd_source_dir <- file.path(source_ext_dir, "orehren", "acvt")

  file.copy(from = file.path(qmd_source_dir, "_quarto.yml"),
            to = file.path(path, "_quarto.yml"))

  file.copy(from = file.path(qmd_source_dir, "academicCV-template.qmd"),
            to = file.path(path, "cv.qmd"))

  # 6. Personalize YAML Header
  # .update_template_yaml(target_qmd, firstname, lastname)

  # 7. Initialize Version Control & Environment
  # if (git_enabled && nzchar(Sys.which("git"))) {
  #   system(paste("git -C", shQuote(path), "init"), ignore.stdout = TRUE, ignore.stderr = TRUE)
  # }

  # if (renv_enabled && requireNamespace("renv", quietly = TRUE)) {
  #   renv::init(project = path, bare = TRUE, restart = FALSE)
  # }

  return(invisible(NULL))
}


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# .update_template_yaml <- function(file_path, firstname, lastname) {
#   if (!requireNamespace("yaml", quietly = TRUE)) return()
#
#   lines <- readLines(file_path)
#   delimiters <- which(lines == "---")
#
#   if (length(delimiters) < 2) return()
#
#   yaml_content <- lines[(delimiters[1] + 1):(delimiters[2] - 1)]
#   body_content <- lines[(delimiters[2] + 1):length(lines)]
#
#   yaml_data <- yaml::read_yaml(text = paste(yaml_content, collapse = "\n"))
#
#   if (!is.null(firstname)) yaml_data$author$firstname <- firstname
#   if (!is.null(lastname))  yaml_data$author$lastname  <- lastname
#
#   new_yaml_str <- yaml::as.yaml(yaml_data, indent.mapping.sequence = TRUE)
#
#   new_content <- c("---", strsplit(new_yaml_str, "\n")[[1]], "---", body_content)
#   writeLines(new_content, file_path)
# }
