# Academic-CV Typst Template for Quarto

This is a [Quarto](https://quarto.org/) extension for creating beautiful, modern, and professional academic CVs and cover letters using the [Typst](https://typst.app/) typesetting system.

![Screenshot of the Template showing a simple cover page of the template with a profile picture, name of the author and contact details highlighted in the center of the document. Accent Color is a greyish blue](https://raw.githubusercontent.com/orehren/acvt/main/screenshot.png#center)

## Features

*   **High-Quality Typesetting:** Built on Typst for clean, professional, and perfectly formatted PDF output.
*   **Data-Driven Content:** Populate your CV directly from a Google Sheet.
*   **Highly Customizable:** Easily change colors, fonts, and more through simple YAML options.
*   **All-in-One:** Generate both your CV and a matching cover letter from a single `.qmd` file.

## Installing

### Recommended Method: R Package & RStudio Template

This is the easiest and most powerful way to use the template. It installs all R package dependencies automatically and makes the project available as a template in the RStudio "New Project" wizard.

1.  **Install the R Package from GitHub:**
    Open your R console (or RStudio) and run the following commands:
    ```r
    # Install devtools if you don't have it already
    if (!requireNamespace("devtools", quietly = TRUE)) {
      install.packages("devtools")
    }
    # Install the package
    devtools::install_github("orehren/academicCVTemplate")
    ```

2.  **Restart RStudio:**
    You must restart your RStudio session for the project template to appear.

3.  **Create a New Project:**
    Go to **File > New Project... > New Directory**. You will now see "Academic CV Project" in the list of project types. Select it to create a new, ready-to-use CV project.

### Alternative Method: Manual Quarto Installation

If you are not using RStudio or prefer a manual setup, you can install the Quarto extension directly.

```bash
# To create a new project with the template
quarto use template orehren/academicCVTemplate

# To add the extension to an existing project
quarto add orehren/academicCVTemplate
```

**Note:** With this method, you must manually install the required R packages. Please see the full documentation for the list of packages

## Documentation

**For complete instructions on how to install, use, and customize this template, please visit the official documentation website: [https://orehren.github.io/acvt](https://orehren.github.io/acvt/)**

The full documentation includes:
*   A step-by-step **Installation Guide**.
*   A hands-on **Tutorial**.
*   A **Complete YAML Reference** for all configuration options.
*   An **Advanced Styling Guide**.

## Acknowledgements

This project was inspired by and builds upon the work of several open-source projects, including Awesome-CV and quarto-awesomecv-typst. For a full list of acknowledgements, please see the [documentation](https://orehren.github.io/acvt/).
