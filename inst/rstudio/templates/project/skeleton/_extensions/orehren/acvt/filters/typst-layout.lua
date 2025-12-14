-- =============================================================================
-- 1. CONSTANTS
-- =============================================================================

local t_insert = table.insert
local t_concat = table.concat
local s_format = string.format
local p_write  = pandoc.write
local p_pandoc = pandoc.Pandoc
local p_raw    = pandoc.RawBlock

local IGNORED_CLASSES = {
  ["grid"] = true,
  ["cv-row"] = true,
  ["html-hidden"] = true,
  ["cv-section-container"] = true,
  ["publication-list"] = true,
  ["publication-group"] = true
}

local TYPST_STRING_ESCAPE = {
  ["\\"] = "\\\\",
  ['"']  = '\\"'
}


-- =============================================================================
-- 2. UTILITIES
-- =============================================================================

local function extract_function_name(classes)
  for _, class in ipairs(classes) do
    if not IGNORED_CLASSES[class] then
      return class
    end
  end
  return "resume-entry"
end

local function convert_blocks_to_typst_string(blocks)
  local doc = p_pandoc(blocks)
  local typst_code = p_write(doc, "typst")
  return typst_code:match("^%s*(.-)%s*$")
end

local function escape_for_typst_string_literal(text)
  return text:gsub('[\\"]', TYPST_STRING_ESCAPE)
end


-- =============================================================================
-- 3. PUBLICATION LIST HANDLER
-- =============================================================================

local function extract_label_from_sidebar(sidebar_div)
  if not sidebar_div then return "Other" end
  local label_str = convert_blocks_to_typst_string(sidebar_div.content)
  return label_str:gsub("^#strong%[(.-)%]$", "%1")
end

local function process_publication_entry(entry_div, target_list, label)
  if entry_div.t ~= "Div" or not entry_div.classes:includes("pub-entry") then return end
  
  local content_str = convert_blocks_to_typst_string(entry_div.content)
  local safe_item = escape_for_typst_string_literal(content_str)
  
  t_insert(target_list, s_format('(label: "%s", item: "%s")', label, safe_item))
end

local function process_publication_group(group_div, target_list)
  if group_div.t ~= "Div" or not group_div.classes:includes("publication-group") then return end
  
  local label_div = group_div.content[1]
  local main_div = group_div.content[2]
  
  if not main_div then return end
  
  local label = extract_label_from_sidebar(label_div)
  
  for _, entry in ipairs(main_div.content) do
    process_publication_entry(entry, target_list, label)
  end
end

local function handle_publication_list(el)
  local typst_items = {}
  
  for _, child in ipairs(el.content) do
    process_publication_group(child, typst_items)
  end
  
  if #typst_items == 0 then
    return p_raw("typst", "#publication-list(())")
  end
  
  local body = t_concat(typst_items, ",\n")
  local typst_call = s_format("#publication-list((\n%s,\n))", body)
  
  return p_raw("typst", typst_call)
end


-- =============================================================================
-- 4. CV ROW HANDLER
-- =============================================================================

local function handle_cv_row(el)
  local func_name = extract_function_name(el.classes)
  local args = {}
  
  for _, child in ipairs(el.content) do
    if child.t == "Div" then
      local content_str = convert_blocks_to_typst_string(child.content)
      t_insert(args, "[" .. content_str .. "]")
    end
  end
  
  local typst_call = s_format("#%s(%s)", func_name, t_concat(args, ", "))
  return p_raw("typst", typst_call)
end


-- =============================================================================
-- 5. MAIN ENTRY POINT
-- =============================================================================

function Div(el)
  if not quarto.doc.is_format("typst") then return nil end
  
  -- Priority 1: Handle the container
  if el.classes:includes("publication-list") then
    return handle_publication_list(el)
  end
  
  -- Priority 2: Handle rows, BUT ignore publication groups
  -- This prevents the bottom-up traversal from converting the groups 
  -- before the parent list can process them.
  if el.classes:includes("cv-row") and not el.classes:includes("publication-group") then
    return handle_cv_row(el)
  end
  
  return nil
end

return { { Div = Div } }
