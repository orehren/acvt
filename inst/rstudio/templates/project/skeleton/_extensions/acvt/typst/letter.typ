// =============================================
// PART: COVER LETTER
// Renders the cover letter page with header,
// recipient address, and body.
// Based on Awesome-CV LaTeX Class
// =============================================

// -- Helper: Combine Contact & Social Lists --
#let get-combined-contacts(author) = {
  let items = ()
  if has-content(author, "contact") { items += author.contact }
  if has-content(author, "socialmedia") { items += author.socialmedia }
  return items
}

// -- Helper: Render the Info Block (Name, Position, Contacts) --
#let render-header-info(author, position, quote) = {
  // 1. PREPARE DATA
  let all-contacts = get-combined-contacts(author)
  let address-item = all-contacts.find(it => it.icon == "fa address-card" or it.icon == "fa location-dot")
  let other-contacts = all-contacts.filter(it => it != address-item)
  
  align(right)[
    #set par(leading: 0.8em)

    // 1. Name 
    #text(font: font-header, size: size-xl, weight: "light", fill: color-text-tertiary)[
      #author.at("firstname", default: "")
    ]
    #text(font: font-header, size: size-xl, weight: "bold", fill: color-text-strong)[
      #author.at("lastname", default: "")
    ]
    
    #v(-5pt)
      
    #if position != none {
        text(font: font-header, size: size-xs, weight: "regular", style: "italic", fill: color-accent)[
          #smallcaps(position)
        ]
    }
    
    #v(-5pt)

    #set text(font: font-header, size: 7pt, fill: color-text-secondary, style: "oblique")
    
    // 3. Address Line
    #if address-item != none {
      text(fill: color-text-tertiary)[
        #render-contact-item(address-item, color-text-tertiary)
      ]
    }
    
    #if other-contacts.len() > 0 {
      let separator = h(0.5em) + text(fill: color-accent)[|] + h(0.5em)
      let chunks = other-contacts.chunks(3)

      for (i, chunk) in chunks.enumerate() {
        render-contact-list(chunk, color-text-secondary, separator: separator)
        if i < chunks.len() - 1 { linebreak() }
      }
    }

    #if quote != none and quote.at("text", default: "") != "" {
      v(1pt)
      text(font: font-header, size: size-label, fill: color-accent, style: "italic")[
        “#quote.text”
      ]
    }
  ]
}

// -- Helper: Header Layout Container --
#let header-section(author, photo, position, quote) = {
  // Padding top ensures we are safe from the physical edge
  pad(top: 0.5cm, bottom: 0.5em)[
    
    // Photo Component
    #let cell-photo = if photo != none and photo != "" {
      box(
        radius: 50%, clip: true, stroke: 0.5pt + color-accent,
        width: 2.2cm, height: 2.2cm,
        image(photo, fit: "cover")
      )
    } else {
      circle(radius: 1.1cm, fill: white)
    }

    // Info Component
    #let cell-info = render-header-info(author, position, quote)

    // Grid Layout
    #grid(
      columns: (auto, 1fr),
      gutter: 0.8cm,
      align: horizon, 
      cell-photo,
      cell-info
    )
  ]
}

// -- Helper: Recipient & Date --
#let recipient-section(recipient, date) = {
  v(8.4mm)

  grid(
    columns: (1fr, 4.5cm),
    gutter: 0pt,
    
    // Left Column: Recipient Info
    align(left)[
      // Name: 11pt Bold (recipienttitlestyle)
      #if recipient.at("addressee", default: "") != "" {
        text(font: font-text, size: 11pt, weight: "bold", fill: color-text-strong)[
          #recipient.addressee \
        ]
      }
      #if recipient.at("address", default: "") != "" {
        text(font: font-text, size: 9pt, weight: "regular", fill: color-text-primary)[
          #smallcaps(recipient.address) \
        ]
      }
      // Zip/City
      #let zip = recipient.at("zip", default: "")
      #let city = recipient.at("city", default: "")
      #if zip != "" or city != "" {
        text(font: font-text, size: 9pt, weight: "regular", fill: color-text-primary)[
          #smallcaps(zip + " " + city)
        ]
      }
    ],

    // Right Column: Date
    align(right)[
      #text(font: font-text, size: 9pt, style: "oblique", fill: color-text-tertiary)[
        #if date != none { date }
      ]
    ]
  )
}

// -- Main Function: Render Cover Letter --
#let render-cover-letter(
  title: none,
  author: (:),
  profile-photo: none,
  recipient: (:),
  date: none,
  subject: none,
  position: none,
  famous-quote: none,
  style: (:), 
  cover_letter_content: [],
) = {
  
  // 1. Page Setup
  set page(
    paper: "a4",
    margin: (top: 3.5cm, bottom: 2cm, left: 2cm, right: 2cm),
    
    header: header-section(author, profile-photo, position, famous-quote),
    header-ascent: 0cm,
    
    footer: [
      #set text(..text-style-footer)
      #upper(if date != none { date })
      #h(1fr)
      #upper(
        author.at("firstname", default: "") + " " +
        author.at("lastname", default: "") + sym.dot.op + " " + 
        (if title != none { title } else { "" })
      )
    ]
  )
  
  set text(..text-style-default, fill: color-text-primary)
  set par(justify: true, leading: 0.8em)

  // 2. Recipient & Date Block
  recipient-section(recipient, date)
  
  // 3. Title (Subject)
  if subject != none and subject != "" {
    v(1em)
    text(font: font-header, size: 10pt, weight: "bold", fill: color-text-strong)[
      #subject
    ]
    v(0.5em)
  } else {
    v(1.5em)
  }

  // 4. Salutation
  let salutation = recipient.at("salutation", default: "Dear")
  let name = recipient.at("name", default: "")
  text(fill: color-text-strong)[#salutation #name,]
  v(0.5em)

  // 5. Body Content
  if cover_letter_content != none {
    text(..text-style-default, fill: color-text-tertiary)[#cover_letter_content]
  }

  // 6. Closing
  v(3.4mm)
  
  let valediction = recipient.at("valediction", default: "Sincerely,")
  block(breakable: false)[
    #text(fill: color-text-strong)[#valediction] \
    #v(0.5em)
    #text(font: font-text, size: 10pt, weight: "bold", fill: color-text-strong)[
      #author.at("firstname", default: "") #author.at("lastname", default: "")
    ]
  ]
}
