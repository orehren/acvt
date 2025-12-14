-- =============================================================================
-- SKILLS RENDERER ORCHESTRATOR
-- Acts as the bridge between the CV Engine and format-specific skill renderers.
-- Unlike the standard CV renderer, this orchestrator passes the full dataset
-- to the strategy to allow for aggregation (grouping) or bulk processing.
-- =============================================================================

local SkillsRenderer = {}

local Engine = require("engine-vsl")

-- =============================================================================
-- 1. ARGUMENT HANDLING
-- =============================================================================

local function prepare_arguments(kwargs)
  -- Defensive Copy: Create a mutable copy to safely modify arguments
  -- without affecting the original Pandoc object.
  local args = {}
  for k, v in pairs(kwargs) do args[k] = v end
  return args
end


-- =============================================================================
-- 2. MAIN ORCHESTRATOR FACTORY
-- =============================================================================

--- Creates a shortcode handler function using a specific renderer strategy.
-- @param renderer_strategy A table containing a 'render' function.
function SkillsRenderer.create_shortcode_handler(renderer_strategy)
  
  return function(args, kwargs, meta)
    
    -- 1. Setup
    local effective_args = prepare_arguments(kwargs)
    
    -- 2. Data Retrieval
    local result = Engine.process_dataset(effective_args, meta)

    -- 3. Error Handling
    if result.error then
      return pandoc.Strong(pandoc.Str("Error: " .. result.error))
    end

    -- 4. Empty State Handling
    -- We check raw_rows because skills logic depends on named columns, 
    -- not positional arguments.
    if #result.raw_rows == 0 then 
      return pandoc.Div({}) 
    end

    -- 5. Delegation
    -- We pass the raw rows (key-value maps) to the strategy.
    -- This allows the strategy to perform grouping (HTML) or table generation (Typst).
    return renderer_strategy.render(result.raw_rows, effective_args)
  end
end

return SkillsRenderer
