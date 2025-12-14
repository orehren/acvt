-- =============================================================================
-- RESEARCH INTERESTS SHORTCODE (TYPST)
-- Wrapper around the generic CV renderer.
-- Injects specific configuration (function name) for the Typst adapter.
-- =============================================================================

local Renderer = require("renderer-cvs")
local TypstStrategy = require("typst-cvs")

local TYPST_FUNCTION_NAME = "research-interests"

-- Create the generic handler using the Typst strategy
local base_handler = Renderer.create_shortcode_handler(TypstStrategy)

local function generate_research_interests_typst(args, kwargs, meta)
  
  kwargs["func"] = TYPST_FUNCTION_NAME
  
  return base_handler(args, kwargs, meta)
end

return { ["research-interests"] = generate_research_interests_typst }
