// =============================================
// MAIN ENTRY POINT
// Orchestrates the document structure (Letter vs CV)
// =============================================

#let resume(doc) = {
  
  // 1. Configuration & Mode Check
  let mode = meta-data.at("render-output", default: "combined")
  let show-letter = mode == "letter-only" or mode == "combined"
  let show-cv     = mode == "cv-only"     or mode == "combined"

  // 2. Render Cover Letter
  if show-letter {
    render-cover-letter(
      title: meta-data.at("title", default: none),
      author: meta-data.at("author", default: (:)),
      profile-photo: meta-data.at("profile-photo", default: none),
      recipient: meta-data.at("recipient", default: (:)),
      date: meta-data.at("date", default: datetime.today()),
      subject: meta-data.at("subject", default: none),
      position: meta-data.at("position", default: none),
      famous-quote: meta-data.at("famous-quote", default: none),
      cover_letter_content: cover_letter_content
    )
  }

  // 3. Render CV
  if show-cv {
    // A. Title Page
    title-page(
      meta-data.at("author", default: (:)),
      profile-photo: meta-data.at("profile-photo", default: none),
      position: meta-data.at("position", default: none)
    )

    // B. Page Settings for Content (Footer, Numbering)
    set page(
      footer: create-footer(meta-data.at("author", default: (:))),
      numbering: "1"
    )
    counter(page).update(1)

    // C. Optional: Famous Quote (CV Version)
    if has-content(meta-data, "famous-quote", "text") {
      let q = meta-data.famous-quote
      quote(
        attribution: q.at("attribution", default: none), 
        block: true, 
        quotes: true
      )[#q.text]
    }

    // D. Optional: About Me
    if has-content(meta-data, "aboutme") {
      set text(..text-style-aboutme)
      align(center)[#meta-data.aboutme]
      v(1em)
    }

    // E. Main Body Content
    doc
  }
}
