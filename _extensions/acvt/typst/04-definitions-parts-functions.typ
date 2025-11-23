// typst/04-definitions-parts-functions.typ
// This file defines the high-level components ("parts") that make up the document structure.
// It includes functions for rendering the cover letter, title page, CV entries, and skills.

// -- Cover Letter Render Logic --
// Constructs the formal cover letter page, including the header grid, date/subject block, and body content.
#let render-cover-letter(
  author,
  color-accent,
  text-style-header,
  recipient: none,
  date: datetime.today(),
  subject: none,
  cover_letter_content: [],
) = {

  // Header Grid: Aligns Sender info (left) and Recipient info (right).
  grid(
    columns: (1fr, 1fr),
    gutter: 2em,
    [
      #text(fill: color-accent, weight: "bold", author.firstname + " " + author.lastname) \
      #find_contact(author, "fa address-card") \
      #find_contact(author, "fa mobile-screen") \
      #find_contact(author, "fa envelope")
    ],
    [
    #if recipient != none or recipient == "" [
      #recipient.name \
      #recipient.address \
      #recipient.zip #recipient.city
      ]
    ]
  )

  v(2em)
  align(right)[#date]
  v(2em)

  // Subject Line with styling
  if subject != none or subject == "" {
    block(
      width: 100%,
      [
        #set text(..text-style-header)
        #align(left)[
            #strong[#text(fill: color-accent)[#subject.slice(0, 3)]#subject.slice(3)]
            #box(width: 1fr, line(length: 99%))
        ]
      ]
    )
    v(2em)
  }

  // Salutation
  if recipient != none or recipient == "" {
    "Dear " + recipient.salutation + ","
  }

  // Main Content (injected from metadata)
  v(1em)
  cover_letter_content

  // Formal Closing
  v(2em)
  "Sincerely,"
  v(1em)
  author.firstname + " " + author.lastname
}

// Generates the standard footer for CV pages.
#let create-footer(author) = {
    set text(..text-style-footer)

    grid(..grid-style-footer,
        [#author.firstname #author.lastname],
        render-author-details-list(author.at("socialmedia"), color-accent, separator: h(0.5em)),
        context text()[#counter(page).display("1/1", both: true)]
    )
}

// -- Title Page Logic --
// Layouts the main introduction page with name, role, photo, and contact details.
#let title-page(author, profile-photo: none) = {
    set page(footer: none)
    v(1fr) // Vertical centering

    grid(..grid-style-titlepage,
        grid.cell(x: 1, y: 1, align: left + bottom)[
            #set text(..text-style-title-name)
            #text(weight: "light")[#author.firstname] #author.lastname \
            #text(..text-style-title-position)[#position]
        ],
        grid.cell(x: 2, y: 1, align: right + bottom)[
            #if profile-photo != none and profile-photo != "" {
                image(profile-photo, width: 100pt)
            }
        ],
        grid.cell(y: 3, colspan: 4)[
            #set text(..text-style-title-contacts)
            #render-author-details-list(author.at("contact"), color-accent, separator: h(0.5em))
        ],
        grid.cell(y: 4, colspan: 4)[
            #set text(..text-style-title-contacts)
            #render-author-details-list(author.at("socialmedia"), color-accent, separator: h(0.5em))
        ]
    )
    v(2fr)

    grid(..grid-style-toc,
        grid.cell(x: 1)[
            #outline(title: [Table of Contents], depth: 1)
        ]
    )
}

// -- CV Section Rendering --

// Applies distinct styles to different columns of a CV entry row (e.g., Year vs Title vs Description).
// This is used by map-cv-entry-values to style the grid cells dynamically.
#let format-section-cells(index, value) = {
    let cell-content = value

    if index == 0 { // Date/Label column
        align(right + horizon)[#text(..text-style-label-accent)[#cell-content]]
    } else if index == 1 { // Main Title column
        align(left + horizon)[#text(..text-style-bold)[#cell-content]]
    } else if calc.even(index) { // Context/Location columns
        align(right + horizon)[#text(..text-style-label)[#cell-content]]
    } else if index == 3 { // Description column
        align(left + horizon)[#text(..text-style-default)[#cell-content]]
    } else { // Generic details
        align(left + horizon)[#text(..text-style-details)[#cell-content]]
    }
}

// Iterates over a flat list of entry values and formats them into a grid layout.
#let map-cv-entry-values(entry-values, startindex: 0) = {
  grid(
    ..entry-values.enumerate(start: startindex).map(((i, value)) =>
      format-section-cells(i, value)
    )
  )
}

// Wrapper for standard CV entries (Work, Education).
#let resume-entry(..args) = {
    let cv-entries = args.named()
    // Evaluate markup strings into content blocks before rendering
    let entry-values = cv-entries.values().map((value) => eval(value, mode: "markup"))
    map-cv-entry-values(entry-values)
}

// Wrapper for Research Interests, starting with a different style index offset.
#let research-interests(..args) = {
    let cv-entries = args.named()
    let entry-values = cv-entries.values().map((value) => eval(value, mode: "markup"))
    map-cv-entry-values(entry-values, startindex: 4)
}


// -- Skill Bar Rendering --

// Helper to construct the visual components of a skill bar (Label, Bar, Level text).
#let skill-bar-components(
  skill,
  value,
  level,
  bar_width: 80%,
  bar_height: 0.4em,
  bar_radius: 1.5pt,
  bar_stroke: (paint: color-nord4, thickness: 0.5pt),
  bar_fill_empty: luma(240),
  bar_fill_progress: color-accent
) = {
  assert(value >= 0.0 and value <= 1.0, message: "skill-bar: 'value' must be between 0.0 and 1.0.")

  let name_component = text(..text-style-skill-name)[#skill]


  let bar_component = box(
    width: bar_width,
    height: bar_height,
    radius: bar_radius,
    fill: none,
    stroke: bar_stroke,
    clip: true
  )[
    #grid(
      columns: (value * 100%, (1.0 - value) * 100%),
      rows: (100%),
      gutter: 0pt,
      if value > 0.0 {
        rect(width: 100%, height: 100%, fill: bar_fill_progress, stroke: none)
      },
      if value < 1.0 {
        rect(width: 100%, height: 100%, fill: bar_fill_empty, stroke: none)
      }
    )
  ]

  let level_component = text(..text-style-skill-level)[#level]

  return (name: name_component, bar: bar_component, level: level_component)
}

// Aggregates skill components into a layout table.
#let create-skill-table(grouped_skills) = {
  for (area, skills_in_area) in grouped_skills.pairs().sorted(key: p => p.at(0)) {
    if skills_in_area.len() == 0 { continue }

    let area_components = skills_in_area.map(entry =>
      skill-bar-components(
        entry.at("skill"),
        float(entry.at("value")),
        entry.at("level")
      )
    )

    let skill_row_cells = area_components.map(comp => comp.name)
    let bar_row_cells = area_components.map(comp => comp.bar)
    let level_row_cells = area_components.map(comp => comp.level)

    let inner_table_content = table(
      columns: skills_in_area.len(),
      stroke: none,
      fill: none,
      align: center + horizon,
      column-gutter: 0.1em,
      row-gutter: 0.04em,
      ..skill_row_cells,
      ..bar_row_cells,
      ..level_row_cells
    )

    map-cv-entry-values((area, inner_table_content))
  }
}

// Main entry point for rendering the skills section.
#let visualize-skills-list(
  skills_list
) = {
  let grouped_skills_map = group-by-field(skills_list, "area")

  if grouped_skills_map.len() == 0 {
    return
  }

  create-skill-table(grouped_skills_map)
}

// -- Publication List Logic --

// Renders the list of publications, grouping them by type (Label).
#let publication-list(entries) = {
  let cells = ()
  let prev-label = none

  for entry in entries {
    let is_new_label = prev-label == none or entry.label != prev-label

    if is_new_label and prev-label != none {
      // Add visual separation between different publication groups.
      cells.push(grid.cell(colspan: 2, inset: (top: 0.2em))[])
    }

    // Left Column: Group Label (only displayed once per group)
    cells.push(
      if is_new_label {
        align(end + top)[#text(..text-style-label)[#entry.label]]
      } else { [] }
    )

    // Right Column: The publication citation
    cells.push(
      align(start + top)[
        #text(..text-style-publication)[#eval(entry.item, mode: "markup")]
      ]
    )
    prev-label = entry.label
  }

  grid(..grid-style-default, ..cells)
}
