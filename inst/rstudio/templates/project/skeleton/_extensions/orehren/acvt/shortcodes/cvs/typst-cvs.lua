-- =============================================================================
-- TYPST RENDERER STRATEGY
-- Generates an intermediate AST structure (Divs) representing the grid.
-- This structure is later intercepted by the 'typst-layout-adapter' filter
-- to generate the actual Typst function calls (#resume-entry).
-- =============================================================================

local TypstRenderer = {}

local Utils = require("../utils")


-- =============================================================================
-- 1. HELPER FUNCTIONS
-- =============================================================================

local function create_cell_div(content_string)
  local blocks = Utils.parse_markdown_string(content_string)
  return pandoc.Div(blocks)
end


-- =============================================================================
-- 2. STRATEGY INTERFACE IMPLEMENTATION
-- =============================================================================

--- Creates a single row for the CV grid (AST representation).
-- @param func_name The name of the function (used as a class for the adapter).
-- @param args_list The list of processed cell contents.
-- @param grid_config Unused for Typst (layout is handled by Typst function).
-- @param extra_classes Unused for Typst (styling is handled by Typst function).
function TypstRenderer.create_row(func_name, args_list, grid_config, extra_classes)
  local cells = {}
  
  for _, content in ipairs(args_list) do
    table.insert(cells, create_cell_div(content))
  end
  
  return pandoc.Div(cells, { class = string.format("cv-row %s", func_name) })
end

return TypstRenderer
