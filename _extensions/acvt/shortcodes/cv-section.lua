-- =============================================================================
-- 1. CORE UTILITIES
-- =============================================================================

local function unwrap(obj)
  if obj == nil then return nil end
  local t = pandoc.utils.type(obj)
  if t == 'MetaList' or t == 'List' then
    local res = {}
    for i, v in ipairs(obj) do res[i] = unwrap(v) end
    return res
  elseif t == 'MetaMap' or t == 'Map' or t == 'table' then
    local res = {}
    for k, v in pairs(obj) do res[k] = unwrap(v) end
    return res
  end
  return pandoc.utils.stringify(obj)
end

local function is_na(val)
  if not val then return true end
  local s = tostring(val)
  return (s == "" or s == "NA" or s == ".na.character")
end

local function clean_string(val)
  local s = tostring(val)
  s = s:gsub("“", '"'):gsub("”", '"'):gsub("‘", "'"):gsub("’", "'")
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
  return '"' .. s .. '"'
end

local function get_arg(kwargs, key, default)
  local val = kwargs[key]
  if not val then return default end
  local s = pandoc.utils.stringify(val)
  if s == "" then return default end
  return s
end

local function read_cv_data_json()
  local f = io.open(".cv_data.json", "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then return nil end
  return quarto.json.decode(content)
end


-- =============================================================================
-- 2. STRING INTERPOLATION
-- =============================================================================

local function interpolate_str(template, row_map)
  local res = template:gsub("{(.-)}", function(col_name)
    col_name = col_name:match("^%s*(.-)%s*$")
    local val = row_map[col_name]

    if is_na(val) then return "" end
    return tostring(val)
  end)
  return res
end

local function extract_used_cols(template)
  local cols = {}
  for col_name in template:gmatch("{(.-)}") do
    col_name = col_name:match("^%s*(.-)%s*$")
    table.insert(cols, col_name)
  end
  return cols
end


-- =============================================================================
-- 3. TIDY SELECT LOGIC (Flattened)
-- =============================================================================

local function get_col_index(cols, name)
  for i, v in ipairs(cols) do
    if v == name then return i end
  end
  return nil
end

local function add_if_unique(list, seen, col)
  if seen[col] then return end
  table.insert(list, col)
  seen[col] = true
end

-- Handles 'start:end' range selection
local function try_select_range(part, all_columns, selected, seen)
  local start_col, end_col = part:match("^([%w_]+):([%w_]+)$")
  if not (start_col and end_col) then return false end

  local idx_start = get_col_index(all_columns, start_col)
  local idx_end = get_col_index(all_columns, end_col)

  if not (idx_start and idx_end) then return false end

  local step = (idx_start <= idx_end) and 1 or -1
  for i = idx_start, idx_end, step do
    add_if_unique(selected, seen, all_columns[i])
  end

  return true
end

-- Helper for try_select_function
local function matches_predicate(col_name, func, arg)
  if func == "starts_with" then return col_name:find("^" .. arg) end
  if func == "ends_with"   then return col_name:find(arg .. "$") end
  if func == "contains"    then return col_name:find(arg, 1, true) end
  if func == "matches"     then return col_name:find(arg) end
  return false
end

-- Handles function selectors like 'starts_with("x")'
local function try_select_function(part, all_columns, selected, seen)
  local func, arg = part:match("^([%w_]+)%(['\"](.+)['\"]%)$")
  if not func then return false end

  for _, col in ipairs(all_columns) do
    if matches_predicate(col, func, arg) then
      add_if_unique(selected, seen, col)
    end
  end

  return true
end

-- Handles exact column name matches
local function select_literal(part, all_columns, selected, seen)
  if get_col_index(all_columns, part) then
    add_if_unique(selected, seen, part)
  end
end

-- Orchestrates the parsing of the selector string without deep nesting
local function resolve_tidy_select(selector_str, all_columns)
  if not selector_str or selector_str == "" then return {} end

  local selected = {}
  local seen = {}

  for part in string.gmatch(selector_str, "([^,]+)") do
    part = part:match("^%s*(.-)%s*$")

    local handled = try_select_range(part, all_columns, selected, seen)

    if not handled then
      handled = try_select_function(part, all_columns, selected, seen)
    end

    if not handled then
      select_literal(part, all_columns, selected, seen)
    end
  end

  return selected
end


-- =============================================================================
-- 4. DATA LOADING (Isolated)
-- =============================================================================

local function get_from_meta(meta, sheet)
  if meta.cv_data and meta.cv_data[sheet] then
    return meta.cv_data[sheet]
  end
  return nil
end

local function get_from_file(sheet)
  local json = read_cv_data_json()
  if json and json.cv_data and json.cv_data[sheet] then
    return json.cv_data[sheet]
  end
  return nil
end

-- Loads data by checking potential sources sequentially
local function load_sheet_data(meta, sheet_name)
  local data = get_from_meta(meta, sheet_name)
  if data then return data end

  data = get_from_file(sheet_name)
  if data then return data end

  return nil
end


-- =============================================================================
-- 5. CONFIG PARSING (Isolated)
-- =============================================================================

-- Extracts arguments starting with 'pos-'
local function parse_pos_mappings(kwargs)
  local templates = {}
  local max_idx = -1

  for k, v in pairs(kwargs) do
    local idx_str = k:match("^pos%-(%d+)$")
    if idx_str then
      local idx = tonumber(idx_str)
      templates[idx] = pandoc.utils.stringify(v)
      if idx > max_idx then max_idx = idx end
    end
  end

  return templates, max_idx
end

-- Identifies columns consumed by explicit mappings to prevent duplication in autofill
local function identify_consumed_columns(mapping_templates)
  local consumed = {}

  for _, tmpl in pairs(mapping_templates) do
    if tmpl:find("{") then
      local cols = extract_used_cols(tmpl)
      for _, c in ipairs(cols) do consumed[c] = true end
    else
      consumed[tmpl] = true
    end
  end

  return consumed
end

-- Initializes state object for autofill iteration
local function init_autofill_state(explicit_consumed, exclude_set)
  local state = {
    ptr = 1,
    consumed = {}
  }
  for k in pairs(explicit_consumed) do state.consumed[k] = true end
  for k in pairs(exclude_set) do state.consumed[k] = true end

  return state
end


-- =============================================================================
-- 6. SLOT PROCESSING LOGIC (Logic/Algorithm Separation)
-- =============================================================================

-- Logic: Determines the value of an explicitly mapped slot
local function get_mapping_value(template, row_map, na_action)
  local val = ""

  if template:find("{") then
    val = interpolate_str(template, row_map)
  elseif row_map[template] then
    val = row_map[template]
    if is_na(val) then
      if na_action == "string" then val = "NA"
      elseif na_action == "keep" then val = "none"
      else val = "" end
    end
  else
    val = template
  end

  return clean_string(val)
end

-- Logic: Formats a found raw value based on NA action
local function format_autofill_result(raw, na_action)
  if not is_na(raw) then
    return clean_string(raw)
  end

  if na_action == "string" then return clean_string("NA") end
  if na_action == "keep" then return "none" end
  return '""'
end

-- Algorithm: Finds the next available column for autofill
local function get_autofill_value(row_map, ordered_keys, state, na_action)
  while state.ptr <= #ordered_keys do
    local key = ordered_keys[state.ptr]
    state.ptr = state.ptr + 1

    if not state.consumed[key] then
      return format_autofill_result(row_map[key], na_action)
    end
  end
  return nil
end

-- Orchestrator: Decides strategy (Mapping vs Autofill) for a specific grid slot
local function process_slot(slot_idx, context, row_map, ordered_keys, autofill_state)
  if context.templates[slot_idx] then
    return get_mapping_value(context.templates[slot_idx], row_map, context.na_action)
  end

  return get_autofill_value(row_map, ordered_keys, autofill_state, context.na_action)
end


-- =============================================================================
-- 7. ROW ORCHESTRATION
-- =============================================================================

local function process_single_row(row_list, context)
  local row_map = {}
  local ordered_keys = {}

  for _, item in ipairs(row_list) do
    row_map[item.key] = item.value
    table.insert(ordered_keys, item.key)
  end

  local autofill_state = init_autofill_state(context.explicit_consumed, context.exclude_set)
  local final_args = {}
  local current_slot = 0
  local safety_limit = context.max_pos + #ordered_keys + 5

  while current_slot < safety_limit do
    -- Stop if we are past mapped slots and have no data left
    if current_slot > context.max_pos and autofill_state.ptr > #ordered_keys then
      break
    end

    local val = process_slot(current_slot, context, row_map, ordered_keys, autofill_state)

    -- Handle gaps in grid
    if not val then
      if current_slot > context.max_pos then break end
      val = '""'
    end

    table.insert(final_args, val)
    current_slot = current_slot + 1
  end

  return final_args
end


-- =============================================================================
-- 8. MAIN ENTRY POINT
-- =============================================================================

local function generate_cv_section(args, kwargs, meta)
  -- 1. Input Validation
  local sheet_name = get_arg(kwargs, "sheet", "")
  local func_name  = get_arg(kwargs, "func", "")

  if sheet_name == "" or func_name == "" then
    return pandoc.Strong(pandoc.Str("Missing sheet/func"))
  end

  -- 2. Data Loading
  local cv_data_source = load_sheet_data(meta, sheet_name)
  if not cv_data_source then
    return pandoc.Strong(pandoc.Str("Sheet not found: " .. sheet_name))
  end

  local rows = unwrap(cv_data_source)
  -- Ensure consistent list-of-rows structure
  if rows[1] and rows[1].key then rows = {rows} end

  if #rows == 0 then return pandoc.RawBlock("typst", "") end

  -- 3. Config Preparation
  local templates, max_pos = parse_pos_mappings(kwargs)

  local all_cols = {}
  for _, field in ipairs(rows[1]) do table.insert(all_cols, field.key) end

  local exclude_list = resolve_tidy_select(get_arg(kwargs, "exclude-cols", ""), all_cols)
  local exclude_set = {}
  for _, c in ipairs(exclude_list) do exclude_set[c] = true end

  local explicit_consumed = identify_consumed_columns(templates)

  local context = {
    templates = templates,
    max_pos = max_pos,
    explicit_consumed = explicit_consumed,
    exclude_set = exclude_set,
    na_action = get_arg(kwargs, "na_action", "omit")
  }

  -- 4. Processing Loop
  local blocks = {}

  for _, row_list in ipairs(rows) do
    local args_list = process_single_row(row_list, context)

    if #args_list > 0 then
      local call = "#" .. func_name .. "(" .. table.concat(args_list, ", ") .. ")"
      table.insert(blocks, call)
    end
  end

  if #blocks == 0 then return pandoc.RawBlock("typst", "") end
  return pandoc.RawBlock("typst", table.concat(blocks, "\n"))
end

return { ["cv-section"] = generate_cv_section }
