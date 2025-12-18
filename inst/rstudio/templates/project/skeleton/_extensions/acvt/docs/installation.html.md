---
title: "Installation Guide"
---

There are two ways to install and use the `acvt` project: via the R package (recommended) or via manual Quarto extension installation.

## Method 1: Installation via R Package (Recommended)

This is the easiest and most powerful way to use the template. This method installs all R package dependencies automatically and makes the project available as a template in the RStudio "New Project" wizard.

### 1. Install the R Package from GitHub

Open your R console (or RStudio) and run the following commands:

```r
# Install devtools if you don't have it already
if (!requireNamespace("devtools", quietly = TRUE)) {
  install.packages("devtools")
}

# Install the acvt package from GitHub
devtools::install_github("orehren/Academic-CVTemplate")
```

### 2. Restart RStudio

You must restart your RStudio session for the project template to appear in the wizard.

### 3. Create a New Project

After restarting, go to **File > New Project... > New Directory**. You will now see "Academic-CV Project" in the list of project types. Select it, fill in your details, and a new, ready-to-use CV project will be created. All R package dependencies will be installed and available to the project.

## Method 2: Alternative Manual Installation

If you prefer not to use the R package or the RStudio template, you can install the Quarto extension manually via the terminal.

## 1. Install the Extension

You can start a new project with the template or add it to an existing Quarto project.

### Option A: Create a New Project (Recommended)

To start fresh with the correct folder structure and files, run this command in your terminal:

```bash
quarto use template orehren/acvt
```

Follow the prompts to name your directory (e.g., `my-cv`).

### Option B: Add to an Existing Project

If you already have a Quarto project, run this command in your project root:

```bash
quarto add orehren/acvt
```

This downloads the extension files into the `_extensions/` directory.

## 2. Configure the Project

This extension uses R to fetch and process data. Regardless of how you installed the extension, you **must** install the required R packages and authenticate with Google.

### The Easy Way: Setup Script (Recommended)

The extension comes with a built-in setup wizard that handles dependencies, authentication, and file copying for you. To run it, simply execute the following command in your R console:

```r
source(list.files(pattern = "setup_acvt.R", recursive = TRUE, full.names = TRUE)[1])
```

This wizard will:
1.  Check and install missing R packages.
2.  Guide you through Google Drive authentication.
3.  (If needed) Copy the template files (`Academic-CV-template.qmd`, `_quarto.yml`) to your project root.

**Note:** If you use the setup script, you are done! You can skip the rest of this section.

---

### The Hard Way: Manual Setup

If you cannot or do not want to use the setup script, you must perform these steps manually.

**1. Install R Packages**
Open your R console and run:

```r
install.packages(c(
  "googledrive",
  "googlesheets4",
  "readxl",
  "jsonlite",
  "cli",
  "purrr",
  "checkmate",
  "rlang"
))
```

**2. Copy Template Files (Only for Option B)**
If you used `quarto add` (Option B), the template files are hidden inside the extension folder. You need to copy them to your project root manually:

*   Copy `_extensions/orehren/acvt/_quarto.yml` to your project root.
*   Copy `_extensions/orehren/acvt/Academic-CV-template.qmd` to your project root (and rename it to `cv.qmd`).

**3. Authenticate**
You will need to handle Google authentication manually in your R session before rendering.

## 3. Next Steps

Once installed, you need to connect your Google Sheet.

*   **Go to [Data Integration](./data_integration.qmd)** to set up authentication and your spreadsheet.
*   **Go to [Tutorial](./tutorial.qmd)** for a walkthrough of the template features.
