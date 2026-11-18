local M = {}
local SOURCES = {
    { table_name = "ItemDetailsData", prefix = "Inventory.Item.", name_field = "ItemName" },
    { table_name = "DanglyDetailsData", prefix = "Inventory.Dangly.", name_field = "DanglyName" },
}

local function inventory_table(name)
    local suffix = "." .. name
    local object = StaticFindObject("/Game/Blueprints/Data/" .. name .. suffix)
    if object and object:IsValid() then
        return object
    end
    for _, candidate in ipairs(FindAllOf("DataTable") or {}) do
        if candidate:IsValid() and candidate:GetFullName():sub(-#suffix) == suffix then
            return candidate
        end
    end
end

local function harvest_usage(entries, values, field)
    values:ForEach(function(_, element)
        local tag = element:get().ItemTag.TagName:ToString()
        if tag ~= "None" and tag ~= "" then
            local entry = entries[tag] or {}
            entry[field] = true
            entries[tag] = entry
        end
    end)
end

local function tsv(value)
    return (value or ""):gsub("[%c]", " ")
end

function M.export(recipes, definitions, path)
    local entries = {}
    local missing = {}
    for _, source in ipairs(SOURCES) do
        local data = inventory_table(source.table_name)
        if not data then
            missing[#missing + 1] = source.table_name
        else
            data:ForEachRow(function(row_name, row)
                row_name = tostring(row_name)
                local ok, name = pcall(function() return row[source.name_field]:ToString() end)
                entries[source.prefix .. row_name] = {
                    row = row_name,
                    name = ok and name or "",
                    source = source.table_name,
                }
            end)
        end
    end

    local custom = {}
    for _, definition in ipairs(definitions) do
        custom[definition.row:lower()] = true
    end
    recipes:ForEachRow(function(row_name, row)
        if not custom[tostring(row_name):lower()] then
            harvest_usage(entries, row.UsedComponents, "ingredient")
            harvest_usage(entries, row.CreatedItems, "output")
        end
    end)

    local tags = {}
    for tag in pairs(entries) do tags[#tags + 1] = tag end
    table.sort(tags)

    local lines = { "tag\trow\tdisplay_name\tsource_table\tstock_ingredient\tstock_output" }
    for _, tag in ipairs(tags) do
        local entry = entries[tag]
        lines[#lines + 1] = table.concat({
            tsv(tag), tsv(entry.row), tsv(entry.name), tsv(entry.source),
            entry.ingredient and "yes" or "", entry.output and "yes" or "",
        }, "\t")
    end

    local file = assert(io.open(path, "wb"))
    local written, write_error = file:write(table.concat(lines, "\n"), "\n")
    local closed, close_error = file:close()
    assert(written, write_error)
    assert(closed, close_error)
    return #tags, missing
end

return M
