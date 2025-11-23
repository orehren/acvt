// typst/page.typ
// This file configures the global page settings for the document.
// It sets up the paper size, margins, and the persistent header element.

#set text(..text-style-default)
#set grid(..grid-style-default)
#set table(..table-style-default)
#set par(justify: true, leading: 0.5em)

#set page(
    paper: "a4",
    margin: (x: 2cm, y: 1.5cm),
    header: align(right)[
        // A horizontal line separating the header from the content
        #box(width: 1fr, line(length: 100%))
        #set text(..text-style-header)
        // Stylized display of the document title (Accent color on first 3 chars)
        #text(fill: color-accent)[#title.slice(0, 3)]#title.slice(3)
    ],
)
