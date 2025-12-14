// =============================================
// PART: CV COMPONENTS
// Includes Title Page, Footer, and List Entries
// (Resume, Research, Publications)
// =============================================

// -- 1. Page Layout Components --

// Creates the footer with page numbering.
#let create-footer(author) = {
  set text(..text-style-footer)
  
  grid(
    ..grid-style-footer,
    [#author.at("firstname", default: "") #author.at("lastname", default: "")],
    
    // Social Media Icons in Footer
    if has-content(author, "socialmedia") {
      render-contact-list(author.socialmedia, color-accent)
    },
    
    context {
      let curr = counter(page).get().first()
      let total = counter(page).final().first()
      align(right)[#curr / #total]
    }
  )
}

// Renders the main Title Page.
#let title-page(author, profile-photo: none, position: none) = {
  set page(footer: none) // No footer on title page
  v(1fr)

  grid(
    ..grid-style-titlepage,

    // Name & Position
    grid.cell(x: 1, y: 1, align: left + bottom)[
      #text(..text-style-title-name)[
        #text(weight: "light")[#author.at("firstname", default: "")] #author.at("lastname", default: "")
      ] \
      #text(..text-style-title-position)[#position]
    ],
    
    // Profile Photo (Circular with Border)
    grid.cell(x: 2, y: 1, align: right + bottom)[
      #if profile-photo != none and profile-photo != "" {
        box(
          radius: 50%, 
          clip: true, 
          stroke: 0.5pt + color-accent,
          width: 100pt, 
          height: 100pt,
          image(profile-photo, fit: "cover")
        )
      }
    ],

    // Contact Info
    grid.cell(y: 3, colspan: 4)[
      #set text(..text-style-title-contacts)
      #if has-content(author, "contact") {
        render-contact-list(author.contact, color-accent)
      }
    ],

    // Social Media
    grid.cell(y: 4, colspan: 4)[
      #set text(..text-style-title-contacts)
      #if has-content(author, "socialmedia") {
        render-contact-list(author.socialmedia, color-accent)
      }
    ]
  )
  
  v(2fr)

  // Table of Contents (optional, based on layout)
  grid(
    ..grid-style-toc,
    grid.cell(x: 1)[
      #outline(title: [Table of Contents], depth: 1)
    ]
  )
}


// -- 2. List Entries (Resume & Research) --

// Helper: Determines style based on column index and entry type.
#let get-cell-style(index, content, type: "default") = {
  if type == "research" {
    // Research: Even = Label (Right), Odd = Details (Left)
    if calc.even(index) {
      align(right + horizon, text(..text-style-label-accent, content))
    } else {
      align(left + horizon, text(..text-style-details, content))
    }
  } else {
    // Resume: Specific columns have specific styles
    if index == 0 {
      align(right + horizon, text(..text-style-label-accent, content)) // Date
    } else if index == 1 {
      align(left + horizon, text(..text-style-bold, content))          // Title
    } else if calc.even(index) {
      align(right + horizon, text(..text-style-label, content))        // Location/Meta
    } else if index == 3 {
      align(left + horizon, text(..text-style-default, content))       // Description
    } else {
      align(left + horizon, text(..text-style-details, content))       // Extra details
    }
  }
}

// Generic renderer for grid rows
#let render-grid-row(values, type) = {
  grid(
    ..values.enumerate().map(((i, value)) => 
      get-cell-style(i, value, type: type)
    )
  )
}

// Public: Resume Entry (Timeline style)
#let resume-entry(..args) = {
  render-grid-row(args.pos(), "default")
}

// Public: Research Interests (Label -> Description)
#let research-interests(..args) = {
  render-grid-row(args.pos(), "research")
}

// -- 3. Publication List --

#let publication-list(entries) = {
  if entries == none { return }

  let cells = ()
  let prev-label = none

  for entry in entries {
    let current-label = entry.at("label", default: none)
    let is-new-group = prev-label != none and current-label != prev-label

    // Add spacing between different groups
    if is-new-group {
      cells.push(grid.cell(colspan: 2, inset: (top: 0.5em))[])
    }

    // Left Column: Label (only shown for the first item of the group)
    cells.push(
      if prev-label != current-label {
        align(end + top, text(..text-style-label, current-label))
      } else { 
        [] 
      }
    )

    // Right Column: Content
    // CRITICAL: We must use eval() here. Quarto/Pandoc passes the bibliography
    // entries as strings containing raw Typst markup (e.g. "#emph[...]").
    // Without eval, these are rendered as literal text.
    cells.push(
      align(start + top, text(..text-style-publication, eval(entry.item, mode: "markup")))
    )

    prev-label = current-label
  }

  grid(..grid-style-default, ..cells)
}
