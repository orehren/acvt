-- =============================================================================
-- CV ENGINE MODULE
-- Core logic for data loading, configuration parsing, and row processing.
-- Strictly separates data retrieval from rendering.
-- =============================================================================

local Engine = {}

local Utils = require("../utils")

-- Constants (Regex Patterns)
local PATTERN_POS_ARG       = "^pos%-(%d+)$"
local PATTERN_INTERPOLATION = "{(.-)}"
local PATTERN_PIPE_SYNTAX   = "^(.-)%s*|%s*(.*)$"
local PATTERN_TRIM          = "^%s*(.-)%s*$"
local PATTERN_RANGE         = "^([%w_]+):([%w_]+)$"
local PATTERN_FUNCTION      = "^([%w_]+)%(['\"](.+)['\"]%)$"

local DEFAULT_NA_ACTION     = "omit"
local DEFAULT_SIDEBAR_WIDTH = 3
local DEFAULT_MAIN_WIDTH    = 9


-- =============================================================================
-- 1. DOMAIN UTILITIES
-- =============================================================================

local function is_value_empty_or_na(value)
  if not value then return true end
  local string_val = tostring(value)
  return (string_val == "" or string_val == "NA" or string_val == ".na.character")
end

local NA_STRATEGIES = {
  string = "NA",
  keep   = nil, -- Returns nil to signal 'skip'
  omit   = ""
}

local function resolve_missing_value(strategy_key)
  local result = NA_STRATEGIES[strategy_key]
  if result == nil and strategy_key ~= "keep" then return "" end
  return result
end


-- =============================================================================
-- 2. COLUMN SELECTION ENGINE
-- =============================================================================

local function find_column_index(available_columns, column_name)
  for index, name in ipairs(available_columns) do
    if name == column_name then return index end
  end
  return nil
end

local function add_unique_column_to_list(target_list, seen_set, column_name)
  if seen_set[column_name] then return end
  table.insert(target_list, column_name)
  seen_set[column_name] = true
end

local function try_select_range(selector_part, available_columns, result_list, seen_set)
  local start_col, end_col = string.match(selector_part, PATTERN_RANGE)
  if not (start_col and end_col) then return false end

  local idx_start = find_column_index(available_columns, start_col)
  local idx_end   = find_column_index(available_columns, end_col)
  
  if not (idx_start and idx_end) then return false end

  local step = (idx_start <= idx_end) and 1 or -1
  for i = idx_start, idx_end, step do
    add_unique_column_to_list(result_list, seen_set, available_columns[i])
  end
  return true
end

local COLUMN_MATCHERS = {
  starts_with = function(col, arg) return string.find(col, "^" .. arg) end,
  ends_with   = function(col, arg) return string.find(col, arg .. "$") end,
  contains    = function(col, arg) return string.find(col, arg, 1, true) end,
  matches     = function(col, arg) return string.find(col, arg) end
}

local function try_select_predicate(selector_part, available_columns, result_list, seen_set)
  local func_name, arg = string.match(selector_part, PATTERN_FUNCTION)
  if not func_name then return false end

  local matcher_function = COLUMN_MATCHERS[func_name]
  if not matcher_function then return false end

  for _, col_name in ipairs(available_columns) do
    if matcher_function(col_name, arg) then
      add_unique_column_to_list(result_list, seen_set, col_name)
    end
  end
  return true
end

local function try_select_literal(selector_part, available_columns, result_list, seen_set)
  if not find_column_index(available_columns, selector_part) then return false end
  add_unique_column_to_list(result_list, seen_set, selector_part)
  return true
end

local SELECTOR_CACHE = {}

local function resolve_column_selectors(selector_string, available_columns)
  if not selector_string or selector_string == "" then return {} end
  
  local cache_key = selector_string .. table.concat(available_columns, "|")
  if SELECTOR_CACHE[cache_key] then return SELECTOR_CACHE[cache_key] end

  local selected_columns = {}
  local seen_columns = {}

  for part in string.gmatch(selector_string, "([^,]+)") do
    local clean_part = string.match(part, PATTERN_TRIM)
    local _ = try_select_range(clean_part, available_columns, selected_columns, seen_columns) 
           or try_select_predicate(clean_part, available_columns, selected_columns, seen_columns) 
           or try_select_literal(clean_part, available_columns, selected_columns, seen_columns)
  end

  SELECTOR_CACHE[cache_key] = selected_columns
  return selected_columns
end


-- =============================================================================
-- 3. TEMPLATE INTERPOLATION ENGINE
-- =============================================================================

local function parse_interpolation_syntax(content_inside_braces)
  local selector_part, separator_part = string.match(content_inside_braces, PATTERN_PIPE_SYNTAX)
  if selector_part then 
    return string.match(selector_part, PATTERN_TRIM), separator_part 
  end
  return string.match(content_inside_braces, PATTERN_TRIM), " "
end

local function process_template_match(content_inside_braces, available_columns, consumed_map)
  local selector, _ = parse_interpolation_syntax(content_inside_braces)
  local resolved_cols = resolve_column_selectors(selector, available_columns)
  for _, col_name in ipairs(resolved_cols) do 
    consumed_map[col_name] = true 
  end
end

local function analyze_template_consumption(template_string, available_columns, consumed_map)
  if string.find(template_string, "{") then
    for content in string.gmatch(template_string, PATTERN_INTERPOLATION) do
      process_template_match(content, available_columns, consumed_map)
    end
    return
  end

  if find_column_index(available_columns, template_string) then
    consumed_map[template_string] = true
  end
end

local function identify_consumed_columns(templates, available_columns)
  local consumed_map = {}
  for _, template_string in pairs(templates) do
    analyze_template_consumption(template_string, available_columns, consumed_map)
  end
  return consumed_map
end

local function interpolate_values(template_string, row_data, available_columns)
  return string.gsub(template_string, PATTERN_INTERPOLATION, function(content)
    local selector, separator = parse_interpolation_syntax(content)
    local target_columns = resolve_column_selectors(selector, available_columns)
    
    local values = {}
    for _, col_name in ipairs(target_columns) do
      local cell_value = row_data[col_name]
      if not is_value_empty_or_na(cell_value) then
        table.insert(values, tostring(cell_value))
      end
    end
    return table.concat(values, separator)
  end)
end


-- =============================================================================
-- 4. CONFIGURATION PARSER
-- =============================================================================

local function parse_positional_argument(arg_name, arg_value, config)
  local position_index = tonumber(string.match(arg_name, PATTERN_POS_ARG))
  if not position_index then return end

  config.templates[position_index] = pandoc.utils.stringify(arg_value)
  if position_index > config.max_position_index then 
    config.max_position_index = position_index 
  end
end

local function parse_shortcode_arguments(kwargs, available_columns)
  local config = {
    templates = {},
    max_position_index = -1,
    excluded_columns_set = {},
    na_strategy = Utils.get_argument_with_default(kwargs, "na_action", DEFAULT_NA_ACTION),
    mode = Utils.get_argument_with_default(kwargs, "mode", "rows")
  }

  for key, value in pairs(kwargs) do
    parse_positional_argument(key, value, config)
  end

  local exclude_string = Utils.get_argument_with_default(kwargs, "exclude-cols", "")
  local excluded_list = resolve_column_selectors(exclude_string, available_columns)
  
  for _, col_name in ipairs(excluded_list) do 
    config.excluded_columns_set[col_name] = true 
  end

  return config
end

local function extract_grid_dimensions(meta)
  local sidebar_width = DEFAULT_SIDEBAR_WIDTH
  local main_width    = DEFAULT_MAIN_WIDTH
  
  if meta['cv-grid'] then
    local grid_meta = meta['cv-grid']
    if grid_meta.sidebar then 
      sidebar_width = tonumber(pandoc.utils.stringify(grid_meta.sidebar)) or sidebar_width 
    end
    if grid_meta.main then 
      main_width = tonumber(pandoc.utils.stringify(grid_meta.main)) or main_width 
    end
  end
  
  return {
    sidebar = sidebar_width,
    main = main_width
  }
end


-- =============================================================================
-- 5. ROW PROCESSING
-- =============================================================================

local function resolve_explicit_template(template_string, context)
  if string.find(template_string, "{") then
    return interpolate_values(template_string, context.row_data, context.available_columns)
  end
  
  local cell_value = context.row_data[template_string]
  if cell_value then
    if is_value_empty_or_na(cell_value) then 
      return resolve_missing_value(context.config.na_strategy) 
    end
    return cell_value
  end
  
  return template_string
end

local function extract_value_if_valid(row_data, column_name, na_strategy)
  local cell_value = row_data[column_name]
  if is_value_empty_or_na(cell_value) then 
    return resolve_missing_value(na_strategy) 
  end
  return cell_value
end

local function create_autofill_iterator(context)
  local column_cursor = 1
  local ordered_columns = context.ordered_columns
  local consumed_map = context.consumed_map
  local row_data = context.row_data
  local na_strategy = context.config.na_strategy
  
  return function()
    while column_cursor <= #ordered_columns do
      local column_name = ordered_columns[column_cursor]
      column_cursor = column_cursor + 1
      
      if not consumed_map[column_name] then
        return extract_value_if_valid(row_data, column_name, na_strategy)
      end
    end
    return nil
  end
end

local function format_output_value(raw_value, slot_index, context)
  if raw_value ~= nil then return raw_value end
  
  if slot_index <= context.config.max_position_index then return ""
  elseif context.config.na_strategy == "keep" then return "" end
  
  return nil
end

local function fetch_next_content(slot_index, context, autofill_iterator)
  local template_string = context.config.templates[slot_index]
  if template_string then
    return resolve_explicit_template(template_string, context)
  end
  return autofill_iterator()
end

local function append_slot_result(formatted_value, slot_index, max_pos, target_list)
  if formatted_value then
    table.insert(target_list, formatted_value)
    return true
  end

  if slot_index > max_pos then return false end

  table.insert(target_list, "")
  return true
end

local function process_single_row(row_item_list, config, global_consumed_map, available_columns)
  local context = {
    row_data = {},
    ordered_columns = {},
    consumed_map = {},
    config = config,
    available_columns = available_columns
  }

  for _, item in ipairs(row_item_list) do
    context.row_data[item.key] = item.value
    table.insert(context.ordered_columns, item.key)
  end

  for k in pairs(global_consumed_map) do context.consumed_map[k] = true end
  for k in pairs(config.excluded_columns_set) do context.consumed_map[k] = true end

  local get_next_autofill = create_autofill_iterator(context)
  local final_arguments = {}
  local current_slot_index = 0
  local safety_limit = config.max_position_index + #context.ordered_columns + 5

  while current_slot_index < safety_limit do
    local raw_value = fetch_next_content(current_slot_index, context, get_next_autofill)

    if raw_value == nil and current_slot_index > config.max_position_index then 
      break 
    end

    local formatted_value = format_output_value(raw_value, current_slot_index, context)
    local should_continue = append_slot_result(formatted_value, current_slot_index, config.max_position_index, final_arguments)
    
    if not should_continue then break end

    current_slot_index = current_slot_index + 1
  end

  return final_arguments
end


-- =============================================================================
-- 6. MAIN ENTRY POINT (EXPOSED)
-- =============================================================================

local function add_column_if_new(column_list, seen_map, key)
  if not key then return end
  if seen_map[key] then return end
  
  table.insert(column_list, key)
  seen_map[key] = true
end

local function scan_row_keys(row, column_list, seen_map)
  for _, field in ipairs(row) do
    add_column_if_new(column_list, seen_map, field.key)
  end
end

local function collect_all_columns(rows)
  local columns = {}
  local seen = {}
  
  for _, row in ipairs(rows) do
    scan_row_keys(row, columns, seen)
  end
  return columns
end

function Engine.process_dataset(kwargs, meta)
  local sheet_name = Utils.get_argument_with_default(kwargs, "sheet", "")
  
  if sheet_name == "" then
    return { error = "Missing 'sheet' argument." }
  end

  local db = Utils.load_json_database()
  local raw_data_source = nil
  
  if meta.cv_data and meta.cv_data[sheet_name] then
    raw_data_source = meta.cv_data[sheet_name]
  elseif db and db.cv_data then
    raw_data_source = db.cv_data[sheet_name]
  end

  if not raw_data_source then
    return { error = "Sheet '" .. sheet_name .. "' not found." }
  end

  local unwrapped_data = Utils.unwrap_pandoc_content(raw_data_source)
  local rows = (pandoc.utils.type(unwrapped_data) == "MetaList" or (type(unwrapped_data)=="table" and unwrapped_data[1])) 
               and unwrapped_data or {unwrapped_data}

  if #rows == 0 then return { rows = {} } end

  local available_columns = collect_all_columns(rows)
  local config = parse_shortcode_arguments(kwargs, available_columns)
  local global_consumed_map = identify_consumed_columns(config.templates, available_columns)
  local grid_dims = extract_grid_dimensions(meta)

  local processed_rows = {}
  for _, row in ipairs(rows) do
    local args = process_single_row(row, config, global_consumed_map, available_columns)
    if #args > 0 then
      table.insert(processed_rows, args)
    end
  end

  return {
    rows = processed_rows,
    raw_rows = rows,
    config = config,
    grid = grid_dims
  }
end

return Engine
