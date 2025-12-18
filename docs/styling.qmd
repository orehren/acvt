---
title: "Advanced Styling Guide"
---

This template provides several ways to customize the visual appearance of your CV and cover letter, from simple YAML options to modifying the underlying Typst stylesheets.

## 1. Basic Styling with YAML

The easiest way to change the look of your document is by using the `style` object in the YAML header.
For a complete list of options, see the [**YAML Reference**](./yaml_reference.qmd#style).

### `color-accent`

This sets the primary color used for heading accents, links, and other highlighted elements.

**Type:** String (Hex color code)

**Example:**

``` yaml
style:
  color-accent: "#2a9d8f" # A dark teal color
```

### `font-header` and `font-text`

These options allow you to change the fonts used in the document.
Provide a list of font names.
Typst will try each font in order until it finds one installed on your system.

**Type:** List of Strings

**Example:**

``` yaml
style:
  font-header: ["Calibri", "Arial", "sans-serif"]
  font-text: ["Garamond", "Times New Roman", "serif"]
```

### Fonts & Rendering

This template is designed to look best with the Roboto, Source Sans and Lato font families.

**Recommendation:**

For the intended visual result, please install these fonts on your system:

-   [Download Robto](https://fonts.google.com/specimen/Roboto)
-   [Download Source Sans Pro](https://fonts.google.com/specimen/Source+Sans+3)
-   [Download Lato](https://fonts.google.com/specimen/Lato)

**Understanding Font Warnings:**

When rendering, you might see warnings in the console like:

`warning: unknown font family: lato`

This is **normal behavior** if you haven't installed the specific fonts.
It means:

1.  Typst looked for "Lato" but couldn't find it on your system.
2.  Typst is now automatically falling back to the built-in fonts (Libertinus Serif).
3.  Your PDF will still be generated correctly, but it will use a serif font style instead of the intended sans-serif style.

## 2. Advanced Styling (Markdown & Attributes)

To ensure your CV renders correctly in the PDF (Typst) format, the template uses Pandoc Native Markdown for styling within your data cells. Beyond rendering fidelity, this approach ensures a format-agnostic structure, significantly simplifying the process of porting the template to other output formats in the future.

### How it Works

Instead of writing format-specific code (like HTML tags or Typst functions), you use standard Markdown syntax. The extension automatically translates this into the correct code for the target output.

### 1. Standard Formatting
You can use standard Markdown for basic styling:
*   **Bold:** `**Text**`
*   **Italic:** `*Text*`
*   **Links:** `[Link Text](https://example.com)`

### 2. Colors & Typography (Bracketed Spans)
To apply specific colors or font styles, use Pandoc's **Bracketed Span** syntax: `[Text]{key="value"}`.

**Supported Attributes:**
*   `color`: Hex code (e.g., `"#5e81ac"`) or CSS variable.
*   `font-weight`: e.g., `"bold"`, `"medium"`, `"light"`.
*   `font-style`: e.g., `"italic"`, `"oblique"`.
*   `font-size`: e.g., `"0.8em"` or `"10pt"`.

**Example:**
| Input in Google Sheet | Result |
| :--- | :--- |
| `Research in [Neuroscience]{color="#5e81ac"}` | "Neuroscience" appears in the accent color. |
| `[Important]{font-weight="bold"}` | "Important" appears bold. |

### 3. Line Breaks
Standard Markdown ignores single line breaks. To force a hard line break inside a cell (e.g., for an address), use the custom sequence: **Backslash + Space + Backslash**.

*   **Syntax:** `\ \`
*   **Example:** `Street Name 12 \ \ 12345 City`

## 3. Advanced Styling (Modifying Typst)

For users who want more control, you can directly modify the Typst style files located in the `_extensions/orehren/acvt/typst/` directory.

::: callout-warning
Modifying these files requires some knowledge of the Typst language.
Always make a backup before making changes.
:::

### Key Files

-   **`theme.typ`:** This is the **Design System**.
    It defines the color palette (mapped to semantic names like `color-text-main`), font families, sizes, and reusable text styles.
    This is the best place to start for most visual changes.
    For example, you can adjust the semantic color mapping or font sizes:

    ``` typst
    // in theme.typ
    #let color-text-strong = rgb("#000000") // Change headlines to pure black
    #let size-lg = 18pt                     // Increase headline size
    ```

-   **`typst-show.typ`:** This file controls the appearance of specific document elements, like headings or blockquotes, using `#show` rules.
    For example, you could change the style of a level-2 heading to use the accent color:

    ``` typst
    // in typst-show.typ
    #show heading.where(level: 2): set text(
      fill: color-accent, 
      weight: "bold"
    )
    ```

-   **`cv-parts.typ` & `letter.typ`:** These files contain the functions that render the actual layout components (e.g., the Title Page, Resume Entries, or the Cover Letter Header).
    Modify these if you want to change the structural layout of the CV or the Letter.

### How to Apply Changes

1.  Open the relevant `.typ` file in a text editor.
2.  Make your desired changes.
3.  Save the file.
4.  Re-render your `.qmd` document with `quarto render`.

Your changes will be immediately reflected in the new PDF output.

### Typst Template Structure

For users who want to modify the core layout, the Typst files are located in the `typst/` subdirectory of the extension's root folder.

### File Overview

| File | Purpose |
|:---|:---|
| `typst-template.typ` | **Main Entry Point.** Orchestrates the logic to switch between Cover Letter and CV modes. |
| `theme.typ` | **Design System.** Defines colors, fonts, sizes, and global styles. |
| `utils.typ` | Low-level helper functions for data manipulation and icons. |
| `letter.typ` | **Cover Letter.** Contains the specific layout logic for the Cover Letter. |
| `cv-parts.typ` | **CV Components.** Renders Title Page, Footer, Resume Entries, and Publication Lists. |
| `skills.typ` | **Skills.** Specialized logic for rendering skill bars and tables. |
| `page.typ` | **Page Layout.** Configures global page dimensions, margins, and the page header. |
| `typst-show.typ` | **Show Rules.** Styles raw Markdown elements (Headings, Blockquotes). |
| `injected-meta-data` | **Auto-generated.** Contains the metadata injected from your YAML. |
| `injected-cover-letter` | **Auto-generated.** Contains the content of the cover letter. |

To customize these files, you can copy them to your project root and update the `template-partials` in your `_extension.yml` (or `_quarto.yml`) to point to your local versions.
