local schema = require("recipes/schema")
local group_rows = require("recipes/group_rows")

local M = {}
local DATA = "/Game/FW/UI/Manufactoring/Data/"
local TABLES = {
    recipes = "DT_ManufactoringRecipies",
    tags = "DT_ManufactoringTags",
    groups = "DT_ManufactoringGroups",
}

function M.is_manufacturing_table(name)
    for _, candidate in pairs(TABLES) do
        if name == candidate then return true end
    end
    return false
end

local function table_path(name)
    return DATA .. name .. "." .. name
end

function M.is_group_table(data)
    if not data or not data:IsValid() or data:GetFName():ToString() ~= TABLES.groups then return false end
    return data:GetFullName():match("^%S+ (.+)$") == table_path(TABLES.groups)
end

function M.find_table(kind)
    local object = StaticFindObject(table_path(TABLES[kind]))
    return object and object:IsValid() and object or nil
end

function M.preload_tables()
    for kind, name in pairs(TABLES) do
        if not M.find_table(kind) then LoadAsset(table_path(name)) end
    end
end

local function stock_outputs(recipes, groups)
    local outputs, visited = {}, {}
    local address = recipes:GetAddress()
    groups:ForEachRow(function(_, group)
        group.ManufactoringRecipies:ForEach(function(_, entry)
            local handle = entry:get()
            local source = handle.DataTable
            local name = handle.RowName:ToString()
            if visited[name] or name:lower():match("^mcr_") then return end
            if not (source and source:IsValid() and source:GetAddress() == address) then return end
            visited[name] = true
            local row = recipes:FindRow(name)
            if not row or row.RecipyTag.TagName:ToString():lower():match("^recipe%.mcr%.") then return end
            for _, output in ipairs(schema.read_items(row.CreatedItems)) do
                outputs[output.tag:lower()] = true
            end
        end)
    end)
    return outputs
end

local function install_recipe(definition, recipes, tags, groups, visible)
    local template = assert(recipes:FindRow(definition.template), "template row missing: " .. definition.template)
    local group = groups:FindRow(definition.group)
    assert(not visible or group, "Manufacturing group missing: " .. definition.group)
    local stock_tag = template.RecipyTag.TagName:ToString()
    local group_tag = template.RecipyGroupTag.TagName:ToString()
    assert(stock_tag:lower() ~= definition.tag:lower(), "custom tag matches template tag")
    local tag_template = tags:FindRow(stock_tag)

    local existing = recipes:FindRow(definition.row)
    local tag_row = tags:FindRow(definition.tag)
    local handles, linked
    if group then handles, linked = group_rows.handles(group, recipes, definition.row) end
    if existing and tag_row and (linked or not visible) and schema.matches(existing, definition, group_tag) then
        return false
    end

    recipes:ForEachRow(function(row_name, row)
        if tostring(row_name):lower() ~= definition.row:lower() then
            assert(row.RecipyTag.TagName:ToString():lower() ~= definition.tag:lower(),
                "recipe tag already belongs to " .. tostring(row_name))
        end
    end)
    if tag_row then
        assert(tag_row.Tag:ToString() == definition.tag, "tag row belongs to another tag: " .. definition.tag)
        assert(existing or definition.tag:match("^Recipe%.MCR%."),
            "tag already exists without its custom recipe: " .. definition.tag)
    end
    assert(not existing or existing.RecipyTag.TagName:ToString() == definition.tag,
        "row already belongs to another recipe: " .. definition.row)

    local previous
    if existing then
        previous = {
            ingredients = schema.read_items(existing.UsedComponents),
            outputs = schema.read_items(existing.CreatedItems),
            name = existing.RecipyName:ToString(),
            group_tag = existing.RecipyGroupTag.TagName:ToString(),
        }
    end

    local added_tag, changed_recipe, changed_group = false, false, false
    local ok, err = pcall(function()
        if not tag_row then
            added_tag = true
            tags:AddRow(definition.tag, tag_template or { Tag = FName(definition.tag) })
            tag_row = assert(tags:FindRow(definition.tag), "tag row could not be read")
            tag_row.Tag = FName(definition.tag)
            assert(tag_row.Tag:ToString() == definition.tag, "tag row did not round-trip")
        end
        if not existing or not schema.matches(existing, definition, group_tag) then
            changed_recipe = true
            if not existing then recipes:AddRow(definition.row, template) end
            local row = assert(recipes:FindRow(definition.row), "recipe row could not be read")
            row.UsedComponents = schema.item_entries(definition.ingredients)
            row.CreatedItems = schema.item_entries(definition.outputs)
            row.RecipyName = FText(definition.name)
            row.RecipyTag.TagName = FName(definition.tag)
            row.RecipyGroupTag.TagName = FName(group_tag)
            assert(schema.matches(row, definition, group_tag), "recipe fields did not round-trip")
        end
        if visible and not linked then
            changed_group = true
            group_rows.link(group, recipes, definition.row, handles)
        end
    end)
    if not ok then
        if changed_group then group.ManufactoringRecipies = handles end
        if changed_recipe and previous then
            existing.UsedComponents = schema.item_entries(previous.ingredients)
            existing.CreatedItems = schema.item_entries(previous.outputs)
            existing.RecipyName = FText(previous.name)
            existing.RecipyGroupTag.TagName = FName(previous.group_tag)
        elseif changed_recipe then
            recipes:RemoveRow(definition.row)
        end
        if added_tag then tags:RemoveRow(definition.tag) end
        error(err, 0)
    end
    return true
end

function M.install(config, log, visibility_policy)
    local recipes, tags, groups = M.find_table("recipes"), M.find_table("tags"), M.find_table("groups")
    if not (recipes and tags and groups) then
        return false
    end

    local definitions = config.definitions
    schema.validate(definitions)
    local visible_rows
    if visibility_policy then
        local ok, result = pcall(visibility_policy, definitions)
        visible_rows = ok and type(result) == "table" and result or {}
        if not ok or type(result) ~= "table" then
            log("Recipe visibility unavailable; keeping custom recipes locked: " .. tostring(result))
        end
    end

    local native_outputs = stock_outputs(recipes, groups)
    local supported, show, active_groups = {}, {}, {}
    for _, definition in ipairs(definitions) do
        local row = definition.row
        supported[row] = not definition.skip_stock_duplicate or not native_outputs[definition.outputs[1].tag:lower()]
        show[row] = supported[row] and (not visible_rows or visible_rows[row] == true)
        if show[row] then active_groups[definition.group] = true end
    end

    local available_groups = {}
    for _, group in ipairs(config.extra_groups) do
        local available = groups:FindRow(group.template)
            and (not group.filter_template or groups:FindRow(group.filter_template))
        if available and active_groups[group.row] then
            local ok, changed = pcall(group_rows.install, group, groups)
            if not ok then
                available = false
                log("Could not install group " .. group.row .. ": " .. tostring(changed))
            elseif changed then
                log("Installed group " .. group.row)
            end
        end
        available_groups[group.row] = not not available
    end
    local eligible = {}
    for _, definition in ipairs(definitions) do
        local row, group = definition.row, definition.group
        local visible = show[row]
        local ok, changed = pcall(install_recipe, definition, recipes, tags, groups, visible)
        if not ok then
            log("Could not install " .. row .. ": " .. tostring(changed))
        else
            local available = available_groups[group]
            if available == nil then available = groups:FindRow(group) ~= nil end
            if supported[row] and available then eligible[row] = true end
            if changed and visible then log("Installed " .. row .. " in " .. group) end
        end
        if ok or not visible then
            for _, custom in ipairs(config.extra_groups) do
                if not visible or custom.row ~= group then
                    group_rows.unlink(groups, recipes, custom.row, row, log)
                end
            end
            if not visible and available_groups[group] == nil then
                group_rows.unlink(groups, recipes, group, row, log)
            end
        end
    end
    for _, custom in ipairs(config.extra_groups) do
        local group = groups:FindRow(custom.row)
        if group and #group.ManufactoringRecipies == 0 then groups:RemoveRow(custom.row) end
    end
    return true, eligible
end

return M
