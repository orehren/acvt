-- =============================================================================
-- PUBLICATIONS TYPST STRATEGY
-- Generates an AST Grid structure identical to the HTML output.
-- This structure is intercepted by the 'typst-layout-adapter' filter
-- to generate the actual Typst function call (#publication-list).
-- =============================================================================

local TypstStrategy = {}

-- We use generic classes here as they serve as signals for the adapter,
-- not necessarily for CSS styling in Typst.
local GRID_SIDEBAR_CLASS = "cv-sidebar"
local GRID_MAIN_CLASS    = "cv-main"


-- =============================================================================
-- 1. HELPER FUNCTIONS
-- =============================================================================

local function create_grid_cell(content_blocks, class_name)
  return pandoc.Div(content_blocks, { class = class_name })
end

local function create_publication_row(label, entries)
  local row_divs = {}
  
  -- Sidebar: Group Label
  local label_block = pandoc.Para(pandoc.Strong(label))
  table.insert(row_divs, create_grid_cell({label_block}, GRID_SIDEBAR_CLASS))
  
  -- Main: List of Entries
  local main_blocks = {}
  for _, entry in ipairs(entries) do
    table.insert(main_blocks, pandoc.Div(entry.blocks, { class = "pub-entry" }))
  end
  table.insert(row_divs, create_grid_cell(main_blocks, GRID_MAIN_CLASS))
  
  return pandoc.Div(row_divs, { class = "cv-row publication-group" })
end

local function group_entries_by_label(entries)
  local groups = {}
  local order = {}
  
  for _, e in ipairs(entries) do
    if not groups[e.label] then
      groups[e.label] = {}
      table.insert(order, e.label)
    end
    table.insert(groups[e.label], e)
  end
  
  return groups, order
end


-- =============================================================================
-- 2. STRATEGY INTERFACE IMPLEMENTATION
-- =============================================================================

function TypstStrategy.render(entries, config)
  local groups, order = group_entries_by_label(entries)
  local grid_rows = {}
  
  for _, label in ipairs(order) do
    table.insert(grid_rows, create_publication_row(label, groups[label]))
  end
  
  -- The class 'publication-list' signals the adapter to process this container.
  -- We also add the config.func_name to allow custom function names in Typst.
  local container_classes = string.format("cv-section-container publication-list %s", config.func_name)
  
  return pandoc.Div(grid_rows, { class = container_classes })
end

return TypstStrategy
