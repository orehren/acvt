// =============================================
// PART: SKILLS
// Renders skill bars and tables.
// =============================================

// -- Helper: Render a single skill bar --
#let render-skill-bar(
  skill-name,
  value,
  level-text,
  bar-width: 100%, // Relative to cell
  height: 0.4em
) = {
  // Validate input
  let progress = float(value)
  if progress < 0.0 or progress > 1.0 {
    panic("Skill value must be between 0.0 and 1.0")
  }

  // 1. Name
  let comp-name = text(..text-style-skill-name, skill-name)

  // 2. Bar (Visual)
  let comp-bar = box(
    width: bar-width,
    height: height,
    radius: height / 2,
    clip: true,
    stroke: (paint: color-text-line, thickness: 0.5pt),
  )[
    #grid(
      columns: (progress * 100%, 1fr),
      rows: (100%),
      gutter: 0pt,
      rect(width: 100%, height: 100%, fill: color-accent, stroke: none), // Filled part
      rect(width: 100%, height: 100%, fill: luma(240), stroke: none)     // Empty part
    )
  ]

  // 3. Level Text
  let comp-level = text(..text-style-skill-level, level-text)

  return (name: comp-name, bar: comp-bar, level: comp-level)
}

// -- Helper: Render a table for a specific skill category --
#let render-skill-category(category, skills) = {
  if skills.len() == 0 { return none }

  // Pre-calculate components for all skills in this category
  let components = skills.map(entry => 
    render-skill-bar(
      entry.at("skill"),
      entry.at("value"),
      entry.at("level")
    )
  )

  // Extract columns for the table
  let col-names = components.map(c => c.name)
  let col-bars  = components.map(c => c.bar)
  let col-levels = components.map(c => c.level)

  // Build the inner table (Name | Bar | Level)
  let inner-table = table(
    columns: skills.len(), // One column per skill in this row
    stroke: none,
    align: center + horizon,
    column-gutter: 1em,
    row-gutter: 0.4em,
    ..col-names,
    ..col-bars,
    ..col-levels
  )

  // Return the full grid row (Category Label | Inner Table)
  // We reuse the 'resume-entry' layout logic implicitly by creating a grid row here
  // that matches the main layout.
  grid(
    ..grid-style-default,
    align(right + horizon, text(..text-style-label-accent, category)),
    inner-table
  )
}

// -- Main Function --
#let visualize-skills-list(skills-list) = {
  if skills-list == none or skills-list.len() == 0 { return }

  // 1. Group by Area
  let grouped = group-by(skills-list, "area")

  // 2. Sort categories alphabetically (optional, keeps order stable)
  let sorted-categories = grouped.keys().sorted()

  // 3. Render each category
  for category in sorted-categories {
    render-skill-category(category, grouped.at(category))
  }
}
