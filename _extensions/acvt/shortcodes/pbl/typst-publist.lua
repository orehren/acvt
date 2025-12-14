-- =============================================================================
-- PUBLICATIONS SHORTCODE (TYPST)
-- Wires the publications renderer with the Typst strategy.
-- =============================================================================

local Renderer = require("renderer-pbl")
local TypstStrategy = require("typst-pbl")

local handler = Renderer.create_shortcode_handler(TypstStrategy)

return { ["publication-list"] = handler }
