-- =============================================================================
-- CV SECTION SHORTCODE (TYPST)
-- Wires the generic renderer with the Typst-specific strategy.
-- =============================================================================

local Renderer = require("renderer-cvs")
local TypstStrategy = require("typst-cvs")

-- Inject the Typst strategy into the generic renderer
local handler = Renderer.create_shortcode_handler(TypstStrategy)

return { ["cv-section"] = handler }
