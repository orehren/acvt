#' Developer Tool: Sync Template to Library
#'
#' Copies the current template files from your source directory (`inst/`)
#' directly to your installed R library.
#'
#' Use this during development to test changes to the skeleton (e.g. cv.qmd)
#' immediately in the "New Project" wizard without a full package reinstall.
#'
#' @return Invisible NULL.
#' @export
dev_sync_template <- function() {

  # 1. Check Context
  # We must be in the package root to find the source files
  if (!file.exists("DESCRIPTION") || !dir.exists("inst")) {
    cli::cli_abort("Please run this function from the root of the 'acvt' source package.")
  }

  # 2. Define Paths
  # Source: The 'inst' folder in your current working directory
  src_skeleton <- file.path(getwd(), "inst", "rstudio", "templates", "project", "skeleton")

  # Target: The installed package location in your R library
  pkg_path <- system.file(package = "acvt")
  if (!nzchar(pkg_path)) {
    cli::cli_abort("Package 'acvt' is not installed in the current library.")
  }
  target_skeleton <- file.path(pkg_path, "rstudio", "templates", "project", "skeleton")

  # 3. Validate
  if (!dir.exists(src_skeleton)) {
    cli::cli_abort("Source skeleton not found at {.path {src_skeleton}}")
  }

  # 4. Perform Sync
  cli::cli_h1("Syncing Template Files")
  cli::cli_alert_info("Source: {.path {src_skeleton}}")
  cli::cli_alert_info("Target: {.path {target_skeleton}}")

  # Remove old target to ensure deleted files are gone
  if (dir.exists(target_skeleton)) {
    unlink(target_skeleton, recursive = TRUE)
  }

  # Copy new files
  # We copy the parent folder structure to ensure permissions are inherited correctly
  dir.create(target_skeleton, recursive = TRUE, showWarnings = FALSE)

  # Copy content of skeleton
  files <- list.files(src_skeleton, full.names = TRUE, recursive = TRUE)

  # We use file.copy on the directory itself to preserve structure easily
  success <- file.copy(
    from = list.files(src_skeleton, full.names = TRUE),
    to = target_skeleton,
    recursive = TRUE
  )

  if (all(success)) {
    cli::cli_alert_success("Template successfully synced!")
    cli::cli_text("You can now open the 'New Project' wizard to see your changes.")
  } else {
    cli::cli_alert_danger("Some files could not be copied. Check permissions.")
  }

  return(invisible(NULL))
}
