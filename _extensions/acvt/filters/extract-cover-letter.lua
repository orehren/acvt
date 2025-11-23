-- extract-cover-letter.lua
-- Moves the "Coverletter" section from body content to metadata.

local section_identifiers = {
  coverletter = true,
}
local collected = {}
local toplevel = 6

local TYPST_METADATA_FILE = quarto.utils.resolve_path("../typst/02-definitions-metadata.typ")


-- Uses append mode because inject_metadata.lua has already created the file.
local function write_coverletter_to_typst(content_blocks)
  if not content_blocks or #content_blocks == 0 then
    return
  end

  local content_as_string = pandoc.write(pandoc.Pandoc(content_blocks), 'typst')
  local typst_definition = '#let cover_letter_content = [' .. content_as_string .. ']\n'

  local file, err = io.open(TYPST_METADATA_FILE, "a")

  if not file then
    pandoc.stderr:write(
      string.format("WARNING (Lua Filter): Could not open '%s': %s\n", TYPST_METADATA_FILE, err)
    )
    return
  end

  file:write(typst_definition)
  file:close()
end


-- State machine to segregate special sections (Coverletter) from the main body.
local function extract_section_content (blocks)
  local body_blocks = {}
  local looking_at_section = false

  local function process_header(block)
    if block.level > toplevel then
      body_blocks[#body_blocks + 1] = block
      return looking_at_section
    end

    toplevel = block.level

    if section_identifiers[block.identifier] then
      collected[block.identifier] = {}
      return block.identifier
    else
      body_blocks[#body_blocks + 1] = block
      return false
    end
  end

  local function process_section_block(block)
    if block.t == 'HorizontalRule' then
      return false
    end

    local collect = collected[looking_at_section]
    collect[#collect + 1] = block
    return looking_at_section
  end


  for _, block in ipairs(blocks) do
    if block.t == 'Header' then
      looking_at_section = process_header(block)
    elseif looking_at_section then
      looking_at_section = process_section_block(block)
    else
      body_blocks[#body_blocks + 1] = block
    end
  end

  return body_blocks
end


Pandoc = function (doc)
  return doc
end

Blocks = function (blocks)
  local body_blocks = extract_section_content(blocks)
  write_coverletter_to_typst(collected["coverletter"])
  return body_blocks
end
