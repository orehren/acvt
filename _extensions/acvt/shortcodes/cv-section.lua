-- cv-section.lua

-- =============================================================================
-- 1. UTILS
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

local function parse_list_arg(val)
  local res = {}
  local s = pandoc.utils.stringify(val)
  if s and s ~= "" then
    for item in string.gmatch(s, "([^,]+)") do
      table.insert(res, item:match("^%s*(.-)%s*$"))
    end
  end
  return res
end

-- =============================================================================
-- 2. TIDY SELECT LOGIC
-- =============================================================================

local function get_col_index(cols, name)
  for i, v in ipairs(cols) do
    if v == name then return i end
  end
  return nil
end

local function resolve_tidy_select(selector_str, all_columns)
  if not selector_str or selector_str == "" then return {} end

  local selected_cols = {}
  local seen = {}

  for part in string.gmatch(selector_str, "([^,]+)") do
    part = part:match("^%s*(.-)%s*$")

    -- 1. Handle Ranges (start:end)
    local start_col, end_col = part:match("^([%w_]+):([%w_]+)$")
    if start_col and end_col then
      local idx_start = get_col_index(all_columns, start_col)
      local idx_end = get_col_index(all_columns, end_col)

      if idx_start and idx_end then
        local step = 1
        if idx_start > idx_end then step = -1 end
        for i = idx_start, idx_end, step do
          local col = all_columns[i]
          if not seen[col] then
            table.insert(selected_cols, col)
            seen[col] = true
          end
        end
      end

    -- 2. Handle Functions (starts_with, etc.)
    else
      local func, arg = part:match("^([%w_]+)%(['\"](.+)['\"]%)$")

      if func then
        for _, col in ipairs(all_columns) do
          local match = false
          if func == "starts_with" then
            if col:find("^" .. arg) then match = true end
          elseif func == "ends_with" then
            if col:find(arg .. "$") then match = true end
          elseif func == "contains" then
            if col:find(arg, 1, true) then match = true end
          elseif func == "matches" then
            if col:find(arg) then match = true end
          end

          if match and not seen[col] then
            table.insert(selected_cols, col)
            seen[col] = true
          end
        end

      -- 3. Handle Exact Names
      else
        if get_col_index(all_columns, part) then
           if not seen[part] then
             table.insert(selected_cols, part)
             seen[part] = true
           end
        end
      end
    end
  end

  return selected_cols
end


-- =============================================================================
-- 3. CORE LOGIC
-- =============================================================================

local function collect_row_fields(row_list, exclude_set, na_mode)
  local fields = {}

  for _, item in ipairs(row_list) do
    local k = item.key
    local v = item.value

    if k and k ~= "" and not exclude_set[k] then

      if is_na(v) then
        if na_mode == "keep" then
          table.insert(fields, { key = k, val = "none" })
        elseif na_mode == "string" then
          table.insert(fields, { key = k, val = '"NA"' })
        end
      else
        local v_clean = clean_string(v)
        table.insert(fields, { key = k, val = v_clean })
      end
    end
  end
  return fields
end

local function apply_combine(fields, opts)
  if #opts.cols == 0 then return fields end

  local target_set = {}
  for _, c in ipairs(opts.cols) do target_set[c] = true end

  local combined_parts = {}
  local remaining_fields = {}
  local consumed_keys = {}

  for _, target_key in ipairs(opts.cols) do
    for _, field in ipairs(fields) do
      if field.key == target_key then
        if field.val ~= "none" then
          local raw_val = field.val:sub(2, -2):gsub('\\"', '"')
          table.insert(combined_parts, opts.prefix .. raw_val)
        end
        consumed_keys[field.key] = true
        break
      end
    end
  end

  for _, field in ipairs(fields) do
    if not consumed_keys[field.key] then
      table.insert(remaining_fields, field)
    end
  end

  if #combined_parts > 0 then
    local joined_text = table.concat(combined_parts, opts.sep)
    local final_val = clean_string(joined_text)
    table.insert(remaining_fields, { key = opts.as, val = final_val })
  end

  return remaining_fields
end

local function apply_order(fields, order_str)
  if not order_str or order_str == "" then return fields end

  local index_moves = {}
  local prio_list = {}
  local has_index_moves = false

  for item in string.gmatch(order_str, "([^,]+)") do
    item = item:match("^%s*(.-)%s*$")
    local col_name, target_pos = item:match("^(.+)=(%d+)$")

    if col_name and target_pos then
      index_moves[tonumber(target_pos)] = col_name
      has_index_moves = true
    else
      table.insert(prio_list, item)
    end
  end

  local fields_map = {}
  for _, f in ipairs(fields) do fields_map[f.key] = f end

  local result = {}
  local used_keys = {}

  if has_index_moves then
    local pool = {}
    local moved_keys_check = {}
    for _, name in pairs(index_moves) do moved_keys_check[name] = true end

    for _, f in ipairs(fields) do
      if not moved_keys_check[f.key] then table.insert(pool, f) end
    end

    local pool_idx = 1
    local total_len = #fields

    for i = 1, total_len do
      if index_moves[i] and fields_map[index_moves[i]] then
        table.insert(result, fields_map[index_moves[i]])
      else
        if pool_idx <= #pool then
          table.insert(result, pool[pool_idx])
          pool_idx = pool_idx + 1
        end
      end
    end
    while pool_idx <= #pool do
      table.insert(result, pool[pool_idx])
      pool_idx = pool_idx + 1
    end
    return result

  else
    for _, target_key in ipairs(prio_list) do
      if fields_map[target_key] then
        table.insert(result, fields_map[target_key])
        used_keys[target_key] = true
      end
    end
    for _, f in ipairs(fields) do
      if not used_keys[f.key] then table.insert(result, f) end
    end
    return result
  end
end

-- =============================================================================
-- 4. MAIN
-- =============================================================================

local function generate_cv_section(args, kwargs, meta)
  local sheet = get_arg(kwargs, "sheet", "")
  local func  = get_arg(kwargs, "func", "")

  if sheet == "" or func == "" then return pandoc.Strong(pandoc.Str("Missing sheet/func")) end
  if not meta.cv_data or not meta.cv_data[sheet] then return pandoc.Strong(pandoc.Str("Sheet not found")) end

  local rows_raw = unwrap(meta.cv_data[sheet])
  local rows = (pandoc.utils.type(rows_raw) == "MetaList" or (type(rows_raw)=="table" and rows_raw[1])) and rows_raw or {rows_raw}

  if #rows == 0 then return pandoc.RawBlock("typst", "") end

  local all_columns = {}
  for _, field in ipairs(rows[1]) do
    if field.key then table.insert(all_columns, field.key) end
  end

  local raw_exclude = get_arg(kwargs, "exclude_cols", "")
  local exclude_cols_list = resolve_tidy_select(raw_exclude, all_columns)

  local exclude_set = {}
  for _, c in ipairs(exclude_cols_list) do exclude_set[c] = true end

  local raw_combine = get_arg(kwargs, "combine_cols", "")
  local combine_cols_list = resolve_tidy_select(raw_combine, all_columns)

  local combine_opts = {
    cols   = combine_cols_list,
    as     = get_arg(kwargs, "combine_as", "details"),
    sep    = get_arg(kwargs, "combine_sep", " "),
    prefix = get_arg(kwargs, "combine_prefix", "")
  }

  local column_order = get_arg(kwargs, "column_order", "")
  local na_action = get_arg(kwargs, "na_action", "omit")

  local blocks = {}

  for _, row_list in ipairs(rows) do
    local fields = collect_row_fields(row_list, exclude_set, na_action)
    fields = apply_combine(fields, combine_opts)
    fields = apply_order(fields, column_order)

    if #fields > 0 then
      local arg_strings = {}
      for _, item in ipairs(fields) do
        table.insert(arg_strings, item.key .. ": " .. item.val)
      end
      local call = "#" .. func .. "(" .. table.concat(arg_strings, ", ") .. ")"
      table.insert(blocks, call)
    end
  end

  if #blocks == 0 then return pandoc.RawBlock("typst", "") end
  return pandoc.RawBlock("typst", table.concat(blocks, "\n"))
end

return { ["cv-section"] = generate_cv_section }
