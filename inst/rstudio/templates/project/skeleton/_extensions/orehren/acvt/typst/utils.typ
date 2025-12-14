// =============================================
// UTILS
// Low-level helper functions for data manipulation
// and basic UI rendering.
// =============================================

#import "@preview/fontawesome:0.6.0": *

// -- Data Manipulation Helpers --

// Ensures a value is always an array.
// Useful for handling single values vs lists from YAML.
#let to-array(val) = {
  if type(val) == array { val } else { (val,) }
}

// Checks if a nested dictionary path exists and has content.
// Usage: has-content(meta-data, "author", "email")
#let has-content(dict, ..keys) = {
  let current = dict
  for key in keys.pos() {
    if current == none or type(current) != dictionary {
      return false
    }
    current = current.at(key, default: none)
  }
  return current != none and current != ""
}

// Groups a list of dictionaries by a specific field key.
// Returns a dictionary where keys are the group names and values are arrays of items.
#let group-by(collection, key) = {
  let grouped = (:)
  
  if collection == none or collection.len() == 0 {
    return grouped
  }

  for item in collection {
    let group-key = item.at(key, default: "Uncategorized")
    let existing = grouped.at(group-key, default: ())
    grouped.insert(group-key, existing + (item,))
  }

  return grouped
}

// -- String Sanitization --

// Cleans up text artifacts from external sources (Pandoc/LaTeX).
#let sanitize-text(text) = {
  if text == none { return "" }
  
  let cleaned = text
  // Replace non-breaking spaces with regular spaces
  cleaned = cleaned.replace(" ", " ") 
  // Remove literal backslashes (Pandoc escaping artifacts)
  cleaned = cleaned.replace("\\", "")
  // Fix specific artifact "end.~NextSentence" -> "end. NextSentence"
  cleaned = cleaned.replace(".~", ". ")

  return cleaned
}

// -- UI / Rendering Helpers --

// Renders a FontAwesome icon or a local SVG.
// Format expected: "fa [brands] icon-name" or "path/to/icon.svg"
#let render-icon(icon-str, color) = {
  if icon-str == none or icon-str == "" { return none }

  // Case A: Local SVG
  if icon-str.ends-with(".svg") {
    return box(image(icon-str))
  }

  // Case B: FontAwesome
  if icon-str.starts-with("fa ") {
    let parts = icon-str.split(" ")
    
    // Format: "fa github"
    if parts.len() == 2 {
      return fa-icon(parts.at(1), fill: color)
    } 
    
    // Format: "fa brands github"
    if parts.len() == 3 and parts.at(1) == "brands" {
      return fa-icon(parts.at(2), fa-set: "Brands", fill: color)
    }
  }

  // Fallback / Error
  assert(false, message: "Invalid icon format: '" + icon-str + "'. Expected 'fa ...' or '*.svg'.")
}

// Renders a single contact/social item (Icon + Text/Link).
#let render-contact-item(item, accent-color) = {
  let icon-code = item.at("icon", default: none)
  let url = item.at("url", default: none)
  let text-raw = item.at("text", default: "")
  let text-clean = sanitize-text(text-raw)

  // 1. Render Icon
  let icon-part = if icon-code != none {
    render-icon(icon-code, accent-color) + h(0.2em)
  } else {
    none
  }

  // 2. Render Text (linked or plain)
  let text-part = if url != none {
    link(url)[#text-clean]
  } else {
    text-clean
  }

  // 3. Combine
  box(icon-part + text-part)
}

// Renders a horizontal list of contact items separated by a spacer.
#let render-contact-list(items, accent-color, separator: h(0.5em)) = {
  if items == none or items.len() == 0 { return none }

  let rendered = items.map(item => render-contact-item(item, accent-color))
  rendered.join(separator)
}

// Finds a specific contact item by its icon name (e.g. to extract email).
#let find-contact(author, icon-name) = {
  if not has-content(author, "contact") { return "" }
  
  let item = author.contact.find(it => it.icon == icon-name)
  if item == none { return "" }

  if "url" in item {
    link(item.url, item.text)
  } else {
    item.text
  }
}

