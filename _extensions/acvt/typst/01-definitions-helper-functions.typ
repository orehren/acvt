// typst/01-definitions-helper-functions.typ
// This module provides general-purpose utility functions used throughout the template.
// These helpers abstract away common tasks like string cleaning, icon rendering, and list formatting.

#import "@preview/fontawesome:0.5.0": *

// Safely retrieve an optional variable, returning a default if it's missing (none).
// This prevents "unknown variable" errors when accessing optional metadata fields.
#let get-optional(value, default) = {
  if value == none { default } else { value }
}

// sanitize text content that might contain artifacts from the Pandoc conversion process.
// This ensures that strings rendered in the PDF look clean and professional.
#let unescape_text(text) = {
  let cleaned = text
  cleaned = cleaned.replace(" ", " ") // Normalize non-breaking spaces
  cleaned = cleaned.replace("\\", "") // Remove escape characters
  cleaned = cleaned.replace(".~", ". ") // Fix specific Pandoc artifacts
  return cleaned
}


// Render an icon based on its type definition (FontAwesome string or SVG path).
// This allows the user to mix and match standard icons with custom SVG graphics transparently.
#let render-icon(icon_string, color) = {
  if icon_string.starts-with("fa ") {
    let parts = icon_string.split(" ")
    if parts.len() == 2 {
      fa-icon(parts.at(1), fill: color)
    } else if parts.len() == 3 and parts.at(1) == "brands" {
      fa-icon(parts.at(2), fa-set: "Brands", fill: color)
    } else {
      assert(false, message: "Invalid FontAwesome icon string format: " + icon_string)
    }
  } else if icon_string.ends-with(".svg") {
    // Treat as a local file path for custom icons.
    box(image(icon_string))
  } else {
    assert(false, message: "Invalid icon string (expected 'fa ...' or '*.svg'): " + icon_string)
  }
}

// Create a visual component for a single contact/social item (Icon + Text/Link).
// Uses a box to keep the icon and text together, preventing awkward line breaks.
#let render-author-detail(item_data, item_accent_color) = {
  let item_icon = item_data.at("icon", default: none)
  let item_url = item_data.at("url", default: none)
  let item_text_raw = item_data.at("text", default: "")
  let item_text = unescape_text(item_text_raw)

  let icon_part = if item_icon != none {
    render-icon(item_icon, item_accent_color) + h(0.2em)
  } else {
    []
  }

  let text_part = if item_url != none {
    link(item_url)[#item_text]
  } else if item_text != "" {
    item_text
  } else {
    []
  }

  return icon_part + text_part
}

// Render a horizontal list of author details separated by a spacer.
// This is used for contact info lines in the header or title page.
#let render-author-details-list(
  list_data,
  item_accent_color,
  separator: h(0.5em)
) = {
  if list_data != none and list_data.len() > 0 {
    let rendered_items = list_data.map(item =>
      box(render-author-detail(item, item_accent_color))
    )
    rendered_items.join(separator)
  } else {
    []
  }
}

// Retrieve specific contact information (like email or phone) by its icon identifier.
// This allows the cover letter to dynamically pull specific contact details from the generic list.
#let find_contact(author, icon_name) = {
  let item = author.contact.find(item => item.icon == icon_name)
  if item != none {
    if "url" in item {
      link(item.url, item.text)
    } else {
      item.text
    }
  } else {
    ""
  }
}

// Organize a flat list of items into a dictionary of lists based on a grouping field.
// Essential for structuring data like skills into categories.
#let group-by-field(raw_fields_list, grouping_field) = {
  let grouped = (:)

  if raw_fields_list == none or raw_fields_list.len() == 0 {
    return grouped
  }

  for field_entry in raw_fields_list {
    let current_field = field_entry.at(grouping_field, default: "Uncategorized")

    if not (current_field in grouped) {
      grouped.insert(current_field, (field_entry,))
    } else {
      let existing_list = grouped.at(current_field)
      grouped.insert(current_field, existing_list + (field_entry,))
    }
  }

  return grouped
}
