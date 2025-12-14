-- =============================================================================
-- CV RENDERER BASE
-- Acts as the orchestrator for CV section shortcodes.
-- Implements the Strategy Pattern: It handles data retrieval and error checking,
-- but delegates the actual AST construction to a specific renderer implementation.
-- =============================================================================

local Base = {}

local Engine = require("engine-cvs")
local Utils  = require("../utils")

local DEFAULT_FUNCTION = "resume-entry"
local CONTAINER_CLASS  = "cv-section-container"


-- =============================================================================
-- 1. ARGUMENT HANDLING
-- =============================================================================

local function prepare_arguments(kwargs)
  -- Defensive Copy: Create a mutable copy of arguments to safely apply defaults
  -- without side effects on the original Pandoc object.
  local args = {}
  for k, v in pairs(kwargs) do args[k] = v end

  local func_name = args["func"]
  
  -- Apply default function if missing or empty
  if not func_name or Utils.ensure_string(func_name) == "" then
    args["func"] = DEFAULT_FUNCTION
  end

  return args
end


-- =============================================================================
-- 2. MAIN ORCHESTRATOR FACTORY
-- =============================================================================

--- Creates a shortcode handler function using a specific renderer strategy.
-- @param renderer_strategy A table containing a 'create_row' function.
function Base.create_shortcode_handler(renderer_strategy)
  
  return function(args, kwargs, meta)
    
    -- 1. Setup
    local effective_args = prepare_arguments(kwargs)
    
    -- 2. Data Retrieval (Delegated to Engine)
    local result = Engine.process_dataset(effective_args, meta)

    -- 3. Error Handling
    if result.error then
      return pandoc.Strong(pandoc.Str("Error: " .. result.error))
    end

    -- 4. Empty State Handling
    if #result.rows == 0 then 
      return pandoc.Div({}) 
    end

    -- 5. Rendering Loop
    -- We iterate over the processed data and ask the strategy to build the AST for each row.
    local content_blocks = {}
    local func_name = effective_args["func"]
    local extra_classes = effective_args["class"]
    
    for _, row_args in ipairs(result.rows) do
      local row_block = renderer_strategy.create_row(func_name, row_args, result.grid, extra_classes)
      table.insert(content_blocks, row_block)
    end

    -- 6. Final Assembly
    return pandoc.Div(content_blocks, { class = CONTAINER_CLASS })
  end
end

return Base
