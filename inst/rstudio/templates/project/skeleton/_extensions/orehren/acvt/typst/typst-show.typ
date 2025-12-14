// =============================================
// SHOW RULES
// Configures how Markdown elements are rendered.
// =============================================

// -- 1. Block Quotes --
#show quote.where(block: true): it => {
  set align(center)
  set text(..text-style-quote)
  
  let attribution = if has-content(meta-data, "famous-quote", "attribution") {
    align(end, [\~ #meta-data.famous-quote.attribution \~])
  }
  
  block(width: 100%, inset: 1em)[
    #if it.quotes { quote(it.body) } else { it.body }
    #attribution
  ]
}

// -- 2. Headings --

// Global Heading Font
#show heading: set text(..text-style-header)

// H1: Section Header (with accent color & line)
#show heading.where(level: 1): it => block(above: 1.5em, below: 1em)[
  #set text(..text-style-header)
  #align(left)[
    #let txt = it.body.text
    #strong[
      // Safety check: only slice if text is long enough
      #if txt.len() >= 3 {
        text(fill: color-accent)[#txt.slice(0, 3)] + txt.slice(3)
      } else {
        text(fill: color-accent)[#txt]
      }
    ]
    #box(width: 1fr, line(length: 100%, stroke: 0.5pt + color-text-primary))
  ]
]

// H2: Sub-section (Thin, Dark Grey)
#show heading.where(level: 2): set text(
  fill: color-text-secondary, 
  size: size-md, 
  weight: "thin"
)

// H3: Small Caps (Light Grey)
#show heading.where(level: 3): it => {
  set text(size: size-sm, fill: color-text-tertiary)
  smallcaps(it.body)
}

// -- 3. Initialize Template --
// Calls the main resume function defined in typst/resume.typ
#show: resume
