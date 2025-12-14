-- =============================================================================
-- PUBLICATIONS RENDERER ORCHESTRATOR
-- Implements the Strategy Pattern for publication lists.
-- =============================================================================

local PublicationsRenderer = {}

local Engine = require("engine-pbl")

function PublicationsRenderer.create_shortcode_handler(renderer_strategy)
  
  return function(args, kwargs, meta)
    
    if kwargs["debug"] == "true" then
      return pandoc.RawBlock("typst", "// Debug: Check console output")
    end

    -- 1. Data Retrieval (Delegated to Engine)
    local result = Engine.process_publications(kwargs)

    -- 2. Error Handling
    if result.error then
      return pandoc.Strong(pandoc.Str(result.error))
    end

    -- 3. Delegation to Strategy
    return renderer_strategy.render(result.entries, result.config)
  end
end

return PublicationsRenderer
