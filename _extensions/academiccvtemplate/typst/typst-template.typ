// =============================================
//  TEMPLATE: Quarto Typst Modern-CV (Optimized)
// =============================================
// Version: 1.5
// Author: Oliver Rehren
// Description: An optimized Typst template for academic CVs,
//              addressing font override logic and show rule errors,
//              while preserving the original visual appearance.
// =============================================


// -- 1. Imports --
// ----------------
// #import "@preview/fontawesome:0.5.0": *
#import "_extensions/academiccvtemplate/typst/helper-functions.typ": *
#import "_extensions/academiccvtemplate/typst/metadata.typ": *
#import "_extensions/academiccvtemplate/typst/styling.typ": *
#import "_extensions/academiccvtemplate/typst/partial-functions.typ": *

#set text(..text-style-default)
#set grid(..grid-style-default)
#set table(..table-style-default)
#set par(justify: true, leading: 0.5em)

#set page(
    paper: "a4",
    margin: (x: 2cm, y: 1.5cm),
    header: align(right)[
        #box(width: 1fr, line(length: 100%))
        #set text(..text-style-header)
        #text(fill: color-accent)[Doc]uments of Application
    ],
)

// -- 7. Main Document Function --
// -------------------------------
#let resume(doc) = {

    // --- Local Show Rules ---
    show quote.where(block: true): it => {
        set align(center)
        set text(..text-style-quote)
        let attribution = if it.attribution != none {
          align(end, [\~ #it.attribution \~])
          } else { none }

        block(
            width: 100%, inset: 1em,
            {
                if it.quotes == true { quote(it.body) } else { it.body }
                attribution
            }
        )
    }

    // --- Document Assembly ---
    // -------------------------

    // 1. Render the Title Page
    title-page(author, profile-photo)

    // 2. Set up page settings for the rest of document (page numbering + footer)
    set page(footer: create-footer(author), numbering: "1")
    counter(page).update(1)

    // 3. Display optional quote
    if famous-quote.text != none {
        quote(attribution: famous-quote.attribution, block: true, quotes: true)[#famous-quote.text]
    }

    // 4. Display optional "About Me" section
    if aboutme != none {
        set text(..text-style-aboutme)
        align(center)[#aboutme]
        v(1em)
    }

    doc

}
