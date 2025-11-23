#let resume(doc) = {

    if render-output == "letter-only" or render-output == "combined" {
      render-cover-letter(author, color-accent, text-style-aboutme,
                          recipient: get-optional(recipient, none),
                          date: get-optional(date, datetime.today()),
                          subject: get-optional(subject, none),
                          cover_letter_content: get-optional(cover_letter_content, none)
                          )
    }

    if render-output == "cv-only" or render-output == "combined" {
      title-page(
        author,
        profile-photo: get-optional(profile-photo, none)
      )

      set page(footer: create-footer(author), numbering: "1")
      counter(page).update(1)

      if famous-quote.text != none {
          quote(attribution: famous-quote.attribution, block: true, quotes: true)[#famous-quote.text]
      }

      if aboutme != none {
          set text(..text-style-aboutme)
          align(center)[#aboutme]
          v(1em)
      }

      doc
    }
}
