local M = {
	state = {
		web_server_job = nil,
		source_bufnr = nil,
		source_winid = nil,
	},
}

local function sorted_keys(tbl)
	local keys = {}
	for key in pairs(tbl) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(left, right)
		return tostring(left) < tostring(right)
	end)
	return keys
end

local function count_keys(tbl)
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

local function is_array(tbl)
	if type(tbl) ~= "table" then
		return false
	end

	local max_index = 0
	local count = 0
	for key in pairs(tbl) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false
		end
		max_index = math.max(max_index, key)
		count = count + 1
	end

	return count == 0 or max_index == count
end

local function truncate(text, limit)
	text = tostring(text)
	if #text <= limit then
		return text
	end
	return text:sub(1, limit - 3) .. "..."
end

local function format_scalar(value)
	local value_type = type(value)
	if value == vim.NIL or value == nil then
		return "null"
	end
	if value_type == "string" then
		return string.format('string "%s"', truncate(value, 42))
	end
	if value_type == "boolean" then
		return string.format("boolean %s", tostring(value))
	end
	if value_type == "number" then
		return string.format("number %s", tostring(value))
	end
	return value_type
end

local function summarize_value(value)
	if value == vim.NIL or value == nil then
		return "null"
	end
	if type(value) ~= "table" then
		return format_scalar(value)
	end
	if is_array(value) then
		return string.format("array[%d]", #value)
	end
	return string.format("object{%d}", count_keys(value))
end

local function schema_type_label(schema)
	if type(schema) ~= "table" then
		return "unknown"
	end

	local schema_type = schema.type
	local label
	if type(schema_type) == "string" then
		label = schema_type
	elseif type(schema_type) == "table" then
		local types = {}
		for _, item in ipairs(schema_type) do
			types[#types + 1] = tostring(item)
		end
		table.sort(types)
		label = table.concat(types, "|")
	elseif schema.properties or schema.additionalProperties ~= nil then
		label = "object"
	elseif schema.items ~= nil then
		label = "array"
	else
		label = "value"
	end

	if schema.nullable and not label:find("null", 1, true) then
		label = label .. "|null"
	end

	return label
end

local function summarize_schema(schema)
	local parts = { schema_type_label(schema) }
	if type(schema) ~= "table" then
		return parts[1]
	end
	if schema.format then
		parts[#parts + 1] = "format=" .. schema.format
	end
	if schema.additionalProperties == false then
		parts[#parts + 1] = "closed"
	end
	if schema.description and schema.description ~= "" then
		parts[#parts + 1] = truncate(schema.description, 40)
	end
	return table.concat(parts, " | ")
end

local function is_json_schema(decoded)
	if type(decoded) ~= "table" then
		return false
	end

	return decoded["$schema"] ~= nil
		or decoded.properties ~= nil
		or decoded.additionalProperties ~= nil
		or decoded.items ~= nil
end

local function value_children(value)
	local children = {}
	if type(value) ~= "table" then
		return children
	end

	if is_array(value) then
		for index, item in ipairs(value) do
			children[#children + 1] = {
				label = string.format("[%d]", index),
				value = item,
			}
		end
		return children
	end

	for _, key in ipairs(sorted_keys(value)) do
		children[#children + 1] = {
			label = tostring(key),
			value = value[key],
			}
	end

	return children
end

local function schema_children(schema)
	local children = {}
	if type(schema) ~= "table" then
		return children
	end

	if type(schema.properties) == "table" then
		for _, key in ipairs(sorted_keys(schema.properties)) do
			children[#children + 1] = {
				label = tostring(key),
				value = schema.properties[key],
			}
		end
	end

	if schema.items ~= nil then
		children[#children + 1] = {
			label = "[]",
			value = schema.items,
		}
	end

	if schema.additionalProperties == true then
		children[#children + 1] = {
			label = "{*}",
			value = { type = "any" },
		}
	elseif type(schema.additionalProperties) == "table" then
		children[#children + 1] = {
			label = "{*}",
			value = schema.additionalProperties,
		}