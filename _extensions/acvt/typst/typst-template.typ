// typst/typst-template.typ
// This file defines the core `resume` function which acts as the document's main controller.
// It determines what parts of the document (Cover Letter, CV, or both) should be rendered based on user configuration.


// -- 7. Main Document Function --
// -------------------------------
#let resume(doc) = {

    // --- Document Assembly ---
    // -------------------------

    // 1. Conditionally render the Cover Letter.
    // This allows users to generate a standalone letter or include it as the first page of their application.
    if render-output == "letter-only" or render-output == "combined" {
      render-cover-letter(author, color-accent, text-style-aboutme,
                          recipient: get-optional(recipient, none),
                          date: get-optional(date, datetime.today()),
                          subject: get-optional(subject, none),
                          cover_letter_content: get-optional(cover_letter_content, none)
                          )
    }

    // 2. Conditionally render the CV.
    if render-output == "cv-only" or render-output == "combined" {
      // Generate the Title Page with personal details and photo.
      title-page(
        author,
        profile-photo: get-optional(profile-photo, none)
      )

      // Initialize page numbering and footer for the main content pages.
      set page(footer: create-footer(author), numbering: "1")
      counter(page).update(1)

      // Optional: Display a motivational quote.
      if famous-quote.text != none {
          quote(attribution: famous-quote.attribution, block: true, quotes: true)[#famous-quote.text]
      }

      // Optional: Display an introductory "About Me" paragraph.
      if aboutme != none {
          set text(..text-style-aboutme)
          align(center)[#aboutme]
          v(1em)
      }

      // Render the main body content provided by Quarto.
      doc
    }
}
