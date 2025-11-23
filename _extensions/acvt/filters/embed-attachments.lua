-- embed-attachments.lua
-- Appends attachments (from YAML) as new pages with headers and images.

function Pandoc(doc)

  local function normalize_to_id(filename)
    if not filename or filename == "" then
      return ""
    end
    local sanitized = string.gsub(filename, "[^%w]", "_")
    return "fig-" .. sanitized
  end

  local function check_file_exists(file)
    local file_handle = io.open(file, "r")

    if file_handle then
      file_handle:close()
      return true
    else
      pandoc.stderr:write(string.format("WARNING (Lua Filter): Attachment file not found: %s\n", file))
      return false
    end
  end

  if not doc.meta.attachments or type(doc.meta.attachments) ~= 'table' then
    return doc
  end

  local attachments = doc.meta.attachments

  for i, item in ipairs(attachments) do

    if type(item) ~= 'table' then
      goto continue
    end

    doc.blocks:insert(pandoc.Para(pandoc.Str("\f")))

    local name = pandoc.utils.stringify(item.name)
    local file = pandoc.utils.stringify(item.file)

    if name and name ~= "" then
      local header = pandoc.Header(2, {pandoc.Str(name)}, {class = "appendix"})
      doc.blocks:insert(header)
    end

    if file and file ~= "" then

      if not check_file_exists(file) then
        goto continue
      end

      local fig_id = normalize_to_id(file)
      local caption = { pandoc.Str(name or "") }
      local image = pandoc.Para(
        pandoc.Image(
          caption,
          file,
          "",
          {
            id = fig_id,
            width = "95%",
            fig_align = "center"
          }
        )
      )
      doc.blocks:insert(image)
    end

    ::continue::
  end

  return doc
end
