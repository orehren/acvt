-- =============================================================================
-- SKILLS TYPST STRATEGY
-- Transforms the raw dataset into a Typst array of dictionaries.
-- This allows the Typst template to handle grouping and rendering logic natively.
-- =============================================================================

local TypstStrategy = {}

local Utils = require("../utils")

local TYPST_FUNCTION_NAME = "visualize-skills-list"


-- =============================================================================
-- 1. HELPER FUNCTIONS
-- =============================================================================

local function convert_row_to_typst_dict(row_item_list)
  local parts = {}
  
  for _, item in ipairs(row_item_list) do
    local key = item.key
    -- We must escape values (e.g. quotes) to ensure valid Typst string syntax
    local val = Utils.escape_text(item.value, Utils.TYPST_ESCAPE_MAP)
    
    -- Format: key: "value"
    table.insert(parts, string.format('%s: "%s"', key, val))
  end
  
  -- Wrap in Typst dictionary syntax: (k: v, k2: v2)
  return string.format('(%s)', table.concat(parts, ", "))
end


-- =============================================================================
-- 2. STRATEGY INTERFACE IMPLEMENTATION
-- =============================================================================

--- Renders the skills dataset as a Typst function call with raw data.
-- @param raw_rows The list of rows (key-value maps) from the engine.
-- @param args The shortcode arguments (unused here).
function TypstStrategy.render(raw_rows, args)
  local dicts = {}
  
  for _, row in ipairs(raw_rows) do
    table.insert(dicts, convert_row_to_typst_dict(row))
  end
  
  -- Construct the full array string: ( (dict1), (dict2) )
  local array_string = string.format('(%s)', table.concat(dicts, ", "))
  
  -- Generate the function call
  local call = string.format("#%s(%s)", TYPST_FUNCTION_NAME, array_string)
  
  return pandoc.RawBlock("typst", call)
end

return TypstStrategy
