#' Update Academic-CV Extension Files in Current Project
#'
#' Updates the `_extensions` folder in the current project to match the version
#' currently installed in the `acvt` R package.
#'
#' Use this function after updating the `acvt` package to apply the latest
#' styles and logic to your existing CV projects.
#'
#' @return Invisible NULL.
#' @export
update_current_cv_project <- function() {

  # 1. Sanity Checks
  if (!file.exists("_quarto.yml")) {
    cli::cli_abort("No '_quarto.yml' found. Please run this function from the root of your CV project.")
  }

  # Check if the project actually uses this extension
  target_dir <- file.path("_extensions", "orehren", "acvt")
  if (!dir.exists(target_dir)) {
    cli::cli_abort("The extension folder {.path {target_dir}} does not exist in this project.")
  }

  # 2. Locate Source in Package
  skeleton_dir <- system.file("rstudio/templates/project/skeleton", package = "acvt")
  if (!nzchar(skeleton_dir)) {
    cli::cli_abort("Could not find the template skeleton in the installed 'acvt' package.")
  }

  source_dir <- file.path(skeleton_dir, "_extensions", "orehren", "acvt")

  # 3. Confirm Action
  cli::cli_h1("Update CV Extension")
  cli::cli_alert_info("This will overwrite the extension files in {.path {target_dir}} with the version from the installed package.")
  cli::cli_alert_warning("Any manual changes you made inside the '_extensions' folder will be lost.")

  if (interactive()) {
    choice <- utils::menu(c("Yes, update files", "No, cancel"), title = "Do you want to proceed?")
    if (choice != 1) {
      cli::cli_alert_danger("Update cancelled.")
      return(invisible(NULL))
    }
  }

  # 4. Perform Update
  cli::cli_progress_step("Updating extension files...", spinner = TRUE)

  # We delete the old folder to ensure deleted files are removed
  unlink(target_dir, recursive = TRUE)

  # Copy the new folder
  # We need to create the parent directory structure if it somehow vanished
  dir.create(dirname(target_dir), recursive = TRUE, showWarnings = FALSE)

  success <- file.copy(from = source_dir, to = dirname(target_dir), recursive = TRUE)

  cli::cli_progress_done()

  if (success) {
    cli::cli_alert_success("Extension successfully updated.")
    cli::cli_text("You should run {.code quarto render} to see the changes.")
  } else {
    cli::cli_alert_danger("Failed to copy files. Please check file permissions.")
  }
}


#' Update Installed Template from GitHub
#'
#' Downloads the latest template files (skeleton) from the GitHub repository
#' and overwrites the files in your installed 'acvt' package library.
#'
#' This allows you to get the latest fixes for the CV template and extension
#' files without needing to reinstall the entire R package.
#'
#' @param repo The GitHub repository in "user/repo" format.
#' @param branch The branch to download from. Defaults to "main".
#' @return Invisible NULL.
#' @export
update_template_from_git <- function(repo = "orehren/acvt", branch = "main") {

  # 1. Locate Installation Target
  # We need to find where the 'acvt' package is currently installed on this machine.
  pkg_path <- system.file(package = "acvt")
  if (!nzchar(pkg_path)) {
    cli::cli_abort("Package 'acvt' is not installed/loaded.")
  }

  target_skeleton <- file.path(pkg_path, "rstudio", "templates", "project", "skeleton")

  # 2. User Confirmation
  cli::cli_h1("Update Template from GitHub")
  cli::cli_alert_info("Target: {.path {target_skeleton}}")
  cli::cli_alert_info("Source: {.val {repo}} (Branch: {.val {branch}})")
  cli::cli_text("This will overwrite the template files in your R library with the latest version from GitHub.")

  if (interactive()) {
    choice <- utils::menu(c("Yes, update now", "No, cancel"), title = "Proceed?")
    if (choice != 1) {
      cli::cli_alert_danger("Update cancelled.")
      return(invisible(NULL))
    }
  }

  # 3. Download & Extract
  cli::cli_progress_step("Downloading latest version...", spinner = TRUE)

  url <- sprintf("https://github.com/%s/archive/refs/heads/%s.zip", repo, branch)
  tmp_zip <- tempfile(fileext = ".zip")
  tmp_dir <- tempdir()

  tryCatch({
    utils::download.file(url, tmp_zip, quiet = TRUE, mode = "wb")
  }, error = function(e) {
    cli::cli_abort("Failed to download from GitHub. Check internet connection or repo name.")
  })

  # Unzip to temp directory
  utils::unzip(tmp_zip, exdir = tmp_dir)

  # 4. Locate Source Skeleton in Download
  # GitHub zips usually extract to a folder named "repo-branch"
  repo_name <- strsplit(repo, "/")[[1]][2]
  extract_root <- file.path(tmp_dir, paste0(repo_name, "-", branch))

  source_skeleton <- file.path(extract_root, "inst", "rstudio", "templates", "project", "skeleton")

  if (!dir.exists(source_skeleton)) {
    cli::cli_abort("Could not find 'inst/rstudio/templates/project/skeleton' in the downloaded archive. Is the repo structure correct?")
  }

  # 5. Perform Update (Hot-Swap)
  cli::cli_progress_step("Installing updates...", spinner = TRUE)

  # We remove the old directory first to ensure deleted files are gone
  unlink(target_skeleton, recursive = TRUE)

  # Create fresh directory
  dir.create(target_skeleton, recursive = TRUE, showWarnings = FALSE)

  # Copy new content
  success <- file.copy(
    from = list.files(source_skeleton, full.names = TRUE),
    to = target_skeleton,
    recursive = TRUE
  )

  cli::cli_progress_done()

  if (all(success)) {
    cli::cli_alert_success("Template updated successfully!")
    cli::cli_text("New projects created via the Wizard will now use the latest version.")
  } else {
    cli::cli_alert_danger("Some files failed to copy. You might need to reinstall the package.")
  }

  # Cleanup temp file (OS handles temp dir usually, but good practice)
  unlink(tmp_zip)

  return(invisible(NULL))
}
