// typst/typst-show.typ
// This file defines the 'show' rules that customize how standard Typst elements are rendered.
// It effectively acts as the theme engine, transforming generic headings and blocks into the specific visual style of the CV.


// Customize block quotes to look like centered, stylized "famous quotes".
#show quote.where(block: true): it => {
    set align(center)
    set text(..text-style-quote)
    let attribution = if famous-quote.at("attribution") != none {
      align(end, [\~ #famous-quote.at("attribution") \~])
      } else { none }

    block(
        width: 100%, inset: 1em,
        {
            if it.quotes == true { quote(it.body) } else { it.body }
            attribution
        }
    )
}

// Global heading font style
#show heading: set text(..text-style-header)

// Level 1 Headings: Major section separators with accent color and a horizontal line.
#show heading.where(level: 1): it => [
    #set block(above: 1.5em, below: 1em)
    #set text(..text-style-header)
    #align(left)[
        // Emphasize the first 3 letters with the accent color
        #strong[#text(fill: color-accent)[#it.body.text.slice(0, 3)]#it.body.text.slice(3)]
        #box(width: 1fr, line(length: 99%))
    ]
]

// Level 2 Headings: Sub-sections for organization within a major block.
#show heading.where(level: 2): it => {
    set text(fill: color-nord2, size: font-size-middle, weight: "thin")
    it.body
}

// Level 3 Headings: Minor labels or smallcaps titles.
#show heading.where(level: 3): it => {
    set text(size: font-size-small, fill: color-nord3)
    smallcaps[#it.body]
}

// Invoke the main resume function to start the document rendering process.
#show: resume.with(

)
