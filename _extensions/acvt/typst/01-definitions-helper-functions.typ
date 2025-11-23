#import "@preview/fontawesome:0.5.0": *

#let get-optional(value, default) = {
  if value == none { default } else { value }
}

#let unescape_text(text) = {
  let cleaned = text
  cleaned = cleaned.replace(" ", " ") // Normalize non-breaking spaces
  cleaned = cleaned.replace("\\", "") // Remove escape characters
  cleaned = cleaned.replace(".~", ". ") // Fix specific Pandoc artifacts
  return cleaned
}

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
    box(image(icon_string))
  } else {
    assert(false, message: "Invalid icon string (expected 'fa ...' or '*.svg'): " + icon_string)
  }
}

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
