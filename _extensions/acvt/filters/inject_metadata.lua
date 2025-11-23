-- inject_metadata.lua
-- Converts document metadata into a raw Typst file defining variables.

local M = {}

local TYPST_METADATA_FILE = quarto.utils.resolve_path("../typst/02-definitions-metadata.typ")

local function escape_typst_string(s)
  if s == nil then return '""' end
  return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

-- Heuristic to distinguish Lua arrays (sequential integers) from dictionaries.
local function is_typst_array(tbl)
  if next(tbl) == nil then
    return true
  end

  local i = 1
  for k, _ in pairs(tbl) do
    if k ~= i then
      return false
    end
    i = i + 1
  end

  return true
end

local to_typ_value

local function format_typst_array(tbl)
  local parts = {}
  for _, item in ipairs(tbl) do
    table.insert(parts, to_typ_value(item))
  end
  return '(' .. table.concat(parts, ", ") .. (#parts > 0 and "," or "") .. ')'
end

local function format_typst_dictionary(tbl)
  local parts = {}
  for key, item in pairs(tbl) do
    local typst_key = tostring(key)
    table.insert(parts, typst_key .. ": " .. to_typ_value(item))
  end
  return '(' .. table.concat(parts, ", ") .. ')'
end

local function is_metadata_clutter(typst_str)
  if not typst_str then return true end
  if typst_str == "none" then return true end
  if typst_str == '()' then return true end
  if typst_str == '""' then return true end
  if typst_str:match("^%(%s*%/%*") then return true end

  return false
end

to_typ_value = function(val)

  if val == nil then
    return "none"
  end

  local meta_type = pandoc.utils.type(val)

  if meta_type == 'string' then
    return escape_typst_string(val)

  elseif meta_type == 'number' or meta_type == 'boolean' then
    return tostring(val)

  elseif meta_type == 'Inlines' or meta_type == 'Blocks' then
    return escape_typst_string(pandoc.utils.stringify(val))

  elseif type(val) == 'table' then
    if is_typst_array(val) then
      return format_typst_array(val)
    else
      return format_typst_dictionary(val)
    end

  else
    return "(/* Unhandled Pandoc Meta type: " .. meta_type .. " */)"
  end
end

function M.Pandoc(doc)
  local quarto_meta = doc.meta or {}
  local typst_definitions = {}

  for key, value in pairs(quarto_meta) do

    if not (type(key) == 'string' and key ~= "") then
      goto continue
    end

    local typst_val_str = to_typ_value(value)

    if is_metadata_clutter(typst_val_str) then
      goto continue
    end

    table.insert(typst_definitions, "#let " .. key .. " = " .. typst_val_str)

    ::continue::
  end

  local typst_definitions_string = table.concat(typst_definitions, "\n") .. "\n"

  local file, err = io.open(TYPST_METADATA_FILE, "w")
  if file then
    file:write(typst_definitions_string)
    file:close()
  else
    pandoc.stderr:write(
      string.format("WARNING (inject_metadata.lua): Could not write to '%s': %s\n", TYPST_METADATA_FILE, err)
    )
  end

  return doc
end

return { { Pandoc = M.Pandoc } }
