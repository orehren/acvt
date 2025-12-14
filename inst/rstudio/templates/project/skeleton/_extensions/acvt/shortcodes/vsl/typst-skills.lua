-- =============================================================================
-- VISUALIZE SKILLS SHORTCODE (TYPST)
-- Wires the generic skills renderer with the Typst-specific strategy.
-- =============================================================================

local Renderer = require("renderer-vsl")
local TypstStrategy = require("typst-vsl")

-- Inject the Typst strategy into the generic renderer
local handler = Renderer.create_shortcode_handler(TypstStrategy)

return { ["visualize-skills"] = handler }
