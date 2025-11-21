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

local function clean(val)
  if not val then return nil end
  local s = tostring(val)
  if s == "" or s == "NA" then return nil end
  s = s:gsub("“", '"'):gsub("”", '"'):gsub("‘", "'"):gsub("’", "'")
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
  return '"' .. s .. '"'
end

-- Helper: Argument sicher auslesen (Fix für leere Keys)
local function get_arg(kwargs, key, default)
  local val = kwargs[key]
  if not val then return default end
  local s = pandoc.utils.stringify(val)
  if s == "" then return default end
  return s
end

-- Helper: Komma-Liste parsen
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
-- 2. LOGIK MODULE
-- =============================================================================

-- A. Sammeln: Wandelt die YAML-Reihen in eine flache Liste um
local function collect_row_fields(row_list, exclude_set)
  local fields = {}
  -- Wir iterieren strikt über die Liste (ipairs), um die Reihenfolge zu wahren
  for _, item in ipairs(row_list) do
    local k = item.key
    local v = item.value

    if k and k ~= "" and not exclude_set[k] then
      local v_clean = clean(v)
      if v_clean then
        table.insert(fields, { key = k, val = v_clean })
      end
    end
  end
  return fields
end

-- B. Kombinieren (Combine Cols)
local function apply_combine(fields, opts)
  if #opts.cols == 0 then return fields end

  local combined_parts = {}
  local remaining_fields = {}
  local consumed_keys = {}

  -- 1. Werte sammeln
  for _, target_key in ipairs(opts.cols) do
    for _, field in ipairs(fields) do
      if field.key == target_key then
        -- Wert ohne äußere Quotes extrahieren
        local raw_val = field.val:sub(2, -2):gsub('\\"', '"')
        table.insert(combined_parts, opts.prefix .. raw_val)
        consumed_keys[field.key] = true
        break
      end
    end
  end

  -- 2. Nicht betroffene Felder behalten
  for _, field in ipairs(fields) do
    if not consumed_keys[field.key] then
      table.insert(remaining_fields, field)
    end
  end

  -- 3. Neuen Key anfügen
  if #combined_parts > 0 then
    local joined_text = table.concat(combined_parts, opts.sep)
    local final_val = clean(joined_text)
    if final_val then
      -- Hier nutzen wir opts.as (was durch get_arg garantiert gefüllt ist)
      table.insert(remaining_fields, { key = opts.as, val = final_val })
    end
  end

  return remaining_fields
end

-- C. Sortieren (Unterstützt "col" und "col=4")
local function apply_order(fields, order_str)
  if not order_str or order_str == "" then return fields end

  local index_moves = {} -- [TargetIndex] = "ColName"
  local prio_list = {}   -- Liste von ColNames
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

  -- Modus 1: Index-Zuweisung (Reißverschluss)
  if has_index_moves then
    local pool = {}
    -- Pool füllen (Reihenfolge der nicht-bewegten Elemente beibehalten)
    local moved_keys_check = {}
    for _, name in pairs(index_moves) do moved_keys_check[name] = true end

    for _, f in ipairs(fields) do
      if not moved_keys_check[f.key] then table.insert(pool, f) end
    end

    local pool_idx = 1
    -- Wir gehen bis zur maximalen Länge (Original + evtl Lücken)
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
    -- Reste anhängen
    while pool_idx <= #pool do
      table.insert(result, pool[pool_idx])
      pool_idx = pool_idx + 1
    end
    return result

  -- Modus 2: Prioritäts-Liste (Einfach nach vorne schieben)
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
-- 3. MAIN
-- =============================================================================
local function generate_cv_section(args, kwargs, meta)
  -- Inputs
  local sheet = get_arg(kwargs, "sheet", "")
  local func  = get_arg(kwargs, "func", "")

  if sheet == "" or func == "" then return pandoc.Strong(pandoc.Str("Missing sheet/func")) end
  if not meta.cv_data or not meta.cv_data[sheet] then return pandoc.Strong(pandoc.Str("Sheet not found")) end

  -- Options
  local exclude_set = {}
  for _, c in ipairs(parse_list_arg(kwargs["exclude_cols"])) do exclude_set[c] = true end

  local combine_opts = {
    cols   = parse_list_arg(kwargs["combine_cols"]),
    as     = get_arg(kwargs, "combine_as", "details"), -- Default greift jetzt sicher
    sep    = get_arg(kwargs, "combine_sep", " "),
    prefix = get_arg(kwargs, "combine_prefix", "")
  }

  local column_order = get_arg(kwargs, "column_order", "")

  -- Daten laden (Liste von Zeilen)
  local rows_raw = unwrap(meta.cv_data[sheet])
  local rows = (pandoc.utils.type(rows_raw) == "MetaList" or (type(rows_raw)=="table" and rows_raw[1])) and rows_raw or {rows_raw}

  local blocks = {}

  -- Verarbeitung Zeile für Zeile
  for _, row_list in ipairs(rows) do
    -- 1. Sammeln
    local fields = collect_row_fields(row_list, exclude_set)

    -- 2. Kombinieren
    fields = apply_combine(fields, combine_opts)

    -- 3. Sortieren
    fields = apply_order(fields, column_order)

    -- 4. Output
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
