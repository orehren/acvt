// =============================================
// THEME
// Defines colors, fonts, and global styles.
// Depends on: meta-data (global), utils.typ
// =============================================

// -- 1. Color Palette --
// Currently Slate & Indigo 

// Slate-900: Darkest, for Headlines/Bold
#let color-text-strong = rgb("#0F172A") 

// Slate-700: Body Text (High Contrast)
#let color-text-primary = rgb("#334155") 

// Slate-600: Secondary Text
#let color-text-secondary = rgb("#475569") 

// Slate-500: Meta Info / Labels
#let color-text-tertiary = rgb("#64748B") 

// Slate-200: Lines / Borders / Backgrounds
#let color-text-line = rgb("#E2E8F0") 


// -- 2. User Configuration --
// Extracting values from meta-data with safe defaults

// Accent Color: Electric Indigo
#let color-accent = {
  let raw-color = meta-data.at("style", default: (:)).at("color-accent", default: "#4F46E5")
  rgb(sanitize-text(raw-color))
}

// Fonts: Ensure they are always arrays + fallback
#let font-fallback = ("Libertinus Serif",)

#let font-header = {
  let user-font = meta-data.at("style", default: (:)).at("font-header", default: "Roboto")
  to-array(user-font) + font-fallback
}

#let font-text = {
  let user-font = meta-data.at("style", default: (:)).at("font-text", default: "Source Sans Pro")
  to-array(user-font) + font-fallback
}

// Grid Configuration (Dynamic Sidebar/Main ratio)
#let cv-grid-cols = {
  let grid-config = meta-data.at("cv-grid", default: (:))
  let sb = float(grid-config.at("sidebar", default: 3))
  let mn = float(grid-config.at("main", default: 9))
  (sb * 1fr, mn * 1fr)
}

// -- 3. Typography Sizes --
#let size-xl     = 22pt
#let size-lg     = 16pt
#let size-md     = 12pt
#let size-norm   = 11pt
#let size-sm     = 10pt
#let size-xs     = 9pt  // Footer
#let size-label  = 8pt
#let size-skill  = 7pt

// -- 4. Text Styles --
// Reusable dictionaries for text properties

#let text-style-default = (
  font: font-text,
  size: size-norm,
  weight: "regular",
  style: "normal",
  fill: color-text-primary,
)

#let text-style-bold = (
  ..text-style-default,
  weight: "bold",
)

#let text-style-header = (
  font: font-header,
  size: size-lg,
  weight: "bold",
  style: "normal",
  fill: color-text-primary
)

#let text-style-footer = (
  font: font-header,
  size: size-xs,
  weight: "regular",
  style: "oblique",
  fill: color-accent
)

#let text-style-table = (
  font: font-text,
  size: size-label,
  weight: "regular",
  style: "oblique",
  fill: color-text-secondary
)

#let text-style-quote = (
  font: font-header,
  size: size-md,
  weight: "regular",
  style: "italic",
  fill: color-accent
)

#let text-style-aboutme = (
  font: font-text,
  size: size-sm,
  weight: "regular",
  style: "oblique",
  fill: color-text-strong
)

#let text-style-publication = (
  font: font-text,
  size: size-sm,
  weight: "regular",
  style: "normal",
  fill: color-text-primary
)

// -- 5. Component Styles --

// Labels (Left side of CV grid)
#let text-style-label = (
  font: font-header,
  size: size-label,
  weight: "light",
  style: "normal",
  fill: color-text-tertiary
)

#let text-style-label-accent = (
  ..text-style-label,
  weight: "regular",
  style: "italic",
  fill: color-accent
)

// Title Page Specifics
#let text-style-title-name = (
  font: font-header,
  size: size-xl,
  weight: "medium",
  style: "normal",
  fill: color-text-strong
)

#let text-style-title-position = (
  font: font-header,
  size: size-norm,
  weight: "regular",
  style: "normal",
  fill: color-accent
)

#let text-style-title-contacts = (
  font: font-header,
  size: size-label,
  weight: "regular",
  style: "oblique",
  fill: color-text-tertiary
)

// Skills
#let text-style-skill-name = (
  font: font-header,
  size: size-skill,
  weight: "bold",
  style: "normal",
  fill: color-text-tertiary
)

#let text-style-skill-level = (
  font: font-header,
  size: size-skill,
  weight: "regular",
  style: "italic",
  fill: color-accent
)

#let text-style-details = (
  font: font-text,
  size: size-label,
  weight: "light",
  style: "normal",
  fill: color-text-primary
)

// -- 6. Layout Grids --

#let grid-style-default = (
  align: center + horizon,
  columns: cv-grid-cols, // Dynamic columns from YAML
  rows: auto,
  gutter: 1em,
  row-gutter: 1em
)

#let grid-style-footer = (
  ..grid-style-default,
  columns: (1fr, auto, 1fr)
)

#let grid-style-titlepage = (
  ..grid-style-default,
  columns: (2cm, 2fr, 1fr, 2cm),
)

#let grid-style-toc = (
  ..grid-style-default,
  columns: (1fr, 1fr)
)

#let table-style-default = (
  columns: (30%, 35%, 35%),
  align: left + horizon,
  stroke: none
)
