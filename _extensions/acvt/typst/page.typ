// =============================================
// PAGE CONFIGURATION
// Sets global page layout and default text styles.
// =============================================

// 1. Set Global Text Defaults
#set text(..text-style-default)
#set par(justify: true, leading: 0.5em)

// 2. Set Global Table/Grid Defaults
#set table(..table-style-default)
#set grid(..grid-style-default)

// 3. Page Layout
#set page(
  paper: "a4",
  margin: (x: 2cm, y: 1.5cm),
  header: context {
    // Only render header if a title exists
    if meta-data.at("title", default: none) != none {
      let title = meta-data.title
      
      // Use a grid to place the line (1fr) to the left of the text (auto)
      grid(
        columns: (1fr, auto),
        align: bottom,  // CHANGED: Aligns the line to the bottom/baseline
        gutter: 0.5em,
        
        // Left: The Line
        line(length: 100%, stroke: 0.5pt + color-text-primary),
        
        // Right: The Title
        {
          set text(..text-style-header, size: size-sm)
          if title.len() >= 3 {
            text(fill: color-accent)[#title.slice(0, 3)] + title.slice(3)
          } else {
            title
          }
        }
      )
    }
  }
)
