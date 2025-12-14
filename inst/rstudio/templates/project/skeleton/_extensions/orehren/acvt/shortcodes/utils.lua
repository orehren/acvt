-- =============================================================================
-- ACVT UTILITIES MODULE
-- Centralizes common logic to enforce DRY principles across filters/shortcodes.
-- =============================================================================

local Utils = {}

-- 1. CONSTANTS
Utils.DEFAULT_DB_PATH = ".cv_data.json"

Utils.TYPST_ESCAPE_MAP = {
  ["\\"] = "\\\\",
  ['"']  = '\\"'
}

Utils.HTML_ESCAPE_MAP = {
  ["<"] = "&lt;",
  [">"] = "&gt;",
  ["&"] = "&amp;",
  ['"'] = "&quot;",
  ["'"] = "&#39;"
}

-- =============================================================================
-- 2. TYPE CHECKING PREDICATES (Self-Documenting Helpers)
-- =============================================================================

function Utils.is_lua_primitive(value)
  local t = type(value)
  return t == "string" or t == "number" or t == "boolean"
end

function Utils.is_pandoc_userdata(value)
  return type(value) == "userdata"
end

function Utils.is_pandoc_ast_node(value)
  return type(value) == "table" and value.t ~= nil and value.c ~= nil
end

function Utils.get_pandoc_type(value)
  local status, type_name = pcall(pandoc.utils.type, value)
  return status and type_name or nil
end

function Utils.is_pandoc_list(type_name)
  return type_name == 'MetaList' or type_name == 'List'
end

function Utils.is_pandoc_map(type_name)
  return type_name == 'MetaMap' or type_name == 'Map' or type_name == 'table'
end

function Utils.is_pandoc_content(type_name)
  return type_name == 'Inlines' or type_name == 'Blocks'
end


-- =============================================================================
-- 3. STRING & TYPE HANDLING
-- =============================================================================

function Utils.ensure_string(obj)
  if obj == nil then return "" end
  
  if Utils.is_lua_primitive(obj) then return obj end
  
  local status, result = pcall(pandoc.utils.stringify, obj)
  if status then return result end
  
  local fallback = tostring(obj)
  
  -- To Filter out C-pointer artifacts from Pandoc
  if string.match(fallback, "^userdata:") then 
    return "" 
  end
  
  return fallback
end

function Utils.trim_whitespace(text)
  return text and string.match(text, "^%s*(.-)%s*$") or ""
end

function Utils.escape_text(text, escape_map)
  return tostring(text):gsub("[<>&\"'\\]", escape_map)
end

function Utils.normalize_markdown_breaks(text)
  if not text then return "" end
  
  local res = string.gsub(text, "\\\\%s+\\\\", "  \n")
  res = string.gsub(res, "\\%s+\\", "  \n")
  
  return res
end

function Utils.parse_markdown_string(markdown_string)
  if not markdown_string or markdown_string == "" then return {} end
  
  local normalized_text = Utils.normalize_markdown_breaks(markdown_string)
  local doc = pandoc.read(normalized_text, "markdown+bracketed_spans")
  
  return doc.blocks
end

-- =============================================================================
-- 4. FILE SYSTEM
-- =============================================================================

function Utils.file_exists(file_path)
  local file_handle = io.open(file_path, "r")
  if file_handle then
    io.close(file_handle)
    return true
  end
  return false
end

function Utils.read_file_content(file_path)
  local file_handle = io.open(file_path, "r")
  if not file_handle then return nil end
  
  local content = file_handle:read("*a")
  file_handle:close()
  return content
end


-- =============================================================================
-- 5. DATA STRUCTURES & PARSING
-- =============================================================================

local function unwrap_list(list_obj) -- recursive function
  local unwrapped = {}
  for i, item in ipairs(list_obj) do 
    unwrapped[i] = Utils.unwrap_pandoc_content(item) 
  end
  return unwrapped
end

local function unwrap_map(map_obj) -- recursive function
  local unwrapped = {}
  for key, value in pairs(map_obj) do 
    unwrapped[key] = Utils.unwrap_pandoc_content(value) 
  end
  return unwrapped
end

local function resolve_table_content(tbl)

  if Utils.is_pandoc_ast_node(tbl) then
    return Utils.ensure_string(tbl)
  end

  local type_name = Utils.get_pandoc_type(tbl)
  
  if not type_name then 
    return Utils.ensure_string(tbl) 
  end

  if Utils.is_pandoc_content(type_name) then
    return Utils.ensure_string(tbl)
  end

  if Utils.is_pandoc_list(type_name) then
    return unwrap_list(tbl)
  end

  if Utils.is_pandoc_map(type_name) then
    return unwrap_map(tbl)
  end

  return Utils.ensure_string(tbl)
end

function Utils.unwrap_pandoc_content(obj) -- recursive function
  if obj == nil then return nil end
  
  if Utils.is_lua_primitive(obj) then
    return obj
  end

  if Utils.is_pandoc_userdata(obj) then
    return Utils.ensure_string(obj)
  end

  if type(obj) == "table" then
    return resolve_table_content(obj)
  end
  
  return Utils.ensure_string(obj)
end

function Utils.parse_comma_separated_string(input_string)
  local result_list = {}
  local safe_string = Utils.ensure_string(input_string)
  
  for item in string.gmatch(safe_string, "([^,]+)") do
    table.insert(result_list, Utils.trim_whitespace(item))
  end
  return result_list
end

function Utils.get_argument_with_default(kwargs, key, default_value)
  local value = kwargs[key]
  if not value then return default_value end
  
  -- local string_value = pandoc.utils.stringify(value) 
  -- keeping the old call as a code comment 
  -- just in case something breaks with ensure_string and trim_whitespace
  
  local string_value = Utils.ensure_string(value)
  string_value = Utils.trim_whitespace(string_value)
  
  return (string_value == "") and default_value or string_value
end

function Utils.load_json_database(file_path)
  local path = file_path or Utils.DEFAULT_DB_PATH
  local content = Utils.read_file_content(path)
  
  if content and content ~= "" then
    return pandoc.json.decode(content)
  end
  return nil
end

return Utils
