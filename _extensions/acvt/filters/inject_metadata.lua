-- inject_metadata.lua
-- This filter bridges the gap between Quarto's YAML metadata and the Typst template.
-- It converts document metadata into a raw Typst file defining variables, enabling
-- the template to access user configuration directly as Typst code.

local M = {}

-- Define the target path for the generated Typst metadata file.
-- We use resolve_path to ensure it works regardless of where the filter is run from.
local TYPST_METADATA_FILE = quarto.utils.resolve_path("../typst/02-definitions-metadata.typ")

-- Safely escape strings to prevent syntax errors in the generated Typst code.
-- This ensures that quotes and backslashes in user data don't break the build.
local function escape_typst_string(s)
  if s == nil then return '""' end
  return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

-- Determine if a Lua table represents a sequential list (array) or a dictionary.
-- This distinction is crucial because Typst has different syntax for arrays () and dictionaries ().
local function is_typst_array(tbl)
  -- Treat empty tables as arrays by default to avoid ambiguity.
  if next(tbl) == nil then
    return true
  end

  local i = 1
  for k, _ in pairs(tbl) do
    if k ~= i then
      return false -- A non-integer key implies a dictionary.
    end
    i = i + 1
  end

  return true
end

local to_typ_value

-- Convert a sequential Lua table into a Typst array literal: (item1, item2, ...)
local function format_typst_array(tbl)
  local parts = {}
  for _, item in ipairs(tbl) do
    table.insert(parts, to_typ_value(item))
  end
  return '(' .. table.concat(parts, ", ") .. (#parts > 0 and "," or "") .. ')'
end

-- Convert a hashed Lua table into a Typst dictionary literal: (key: value, ...)
local function format_typst_dictionary(tbl)
  local parts = {}
  for key, item in pairs(tbl) do
    local typst_key = tostring(key)
    table.insert(parts, typst_key .. ": " .. to_typ_value(item))
  end
  return '(' .. table.concat(parts, ", ") .. ')'
end

-- Filter out empty or meaningless values to keep the metadata file clean.
-- This prevents the Typst template from being cluttered with "none" or empty structures.
local function is_metadata_clutter(typst_str)
  if not typst_str then return true end
  if typst_str == "none" then return true end
  if typst_str == '()' then return true end
  if typst_str == '""' then return true end
  if typst_str:match("^%(%s*%/%*") then return true end

  return false
end

-- Recursively transform Pandoc AST elements and Lua types into their Typst string equivalents.
-- This handles the variety of data types that can appear in Quarto metadata.
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

-- Main entry point for the filter.
-- Iterates over all document metadata, converts it, and writes it to a file.
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

  -- Write the definitions to the specific file required by the Typst template.
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
