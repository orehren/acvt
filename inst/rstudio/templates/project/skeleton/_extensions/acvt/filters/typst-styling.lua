-- =============================================================================
-- TYPST STYLING FILTER
-- Transforms custom Pandoc Span attributes into Typst #text() function calls.
-- =============================================================================

local s_format = string.format
local t_insert = table.insert
local t_concat = table.concat
local p_raw    = pandoc.RawInline
local p_utils  = pandoc.utils


-- =============================================================================
-- 1. HELPER FUNCTIONS
-- =============================================================================

local function build_typst_args(attributes)
  local args = {}
  
  -- 1. Color (fill)
  -- Requires wrapping in rgb() function
  if attributes['color'] then
    t_insert(args, s_format('fill: rgb("%s")', attributes['color']))
  end
  
  -- 2. Font Size (size)
  -- Passed directly (e.g. 8pt)
  if attributes['font-size'] then
    t_insert(args, s_format('size: %s', attributes['font-size']))
  end
  
  -- 3. Font Weight (weight)
  -- Requires quotes as it is a string enum in Typst
  if attributes['font-weight'] then
    t_insert(args, s_format('weight: "%s"', attributes['font-weight']))
  end
  
  -- 4. Font Style (style)
  -- Requires quotes
  if attributes['font-style'] then
    t_insert(args, s_format('style: "%s"', attributes['font-style']))
  end
  
  return args
end


-- =============================================================================
-- 2. MAIN LOGIC
-- =============================================================================

function Span(el)
  local args = build_typst_args(el.attributes)
  
  if #args == 0 then return nil end
  
  -- We must convert the content to a string because we are generating a RawInline.
  -- Standard Pandoc AST cannot be nested inside a RawInline string.
  local content = p_utils.stringify(el.content)
  
  -- Construct: #text(arg1, arg2)[content]
  local typst_code = s_format('#text(%s)[%s]', t_concat(args, ", "), content)
  
  return p_raw("typst", typst_code)
end

return { { Span = Span } }
