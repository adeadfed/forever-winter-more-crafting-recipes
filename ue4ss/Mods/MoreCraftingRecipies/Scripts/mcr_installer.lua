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

function M.find_table(kind)
    local name = TABLES[kind]
    local object = StaticFindObject(DATA .. name .. "." .. name)
    return object and object:IsValid() and object or nil
end

local function validate_items(items, field)
    assert(type(items) == "table" and #items > 0, field .. " must contain at least one item")
    for _, item in ipairs(items) do
        assert(type(item.tag) == "string" and item.tag:match("^Inventory%."),
            field .. " requires a full Inventory tag")
        assert(math.type(item.quantity) == "integer" and item.quantity > 0
            and item.quantity <= 2147483647, field .. " requires a positive integer quantity")
    end
end

function M.validate(definitions)
    local rows, tags = {}, {}
    for _, recipe in ipairs(definitions) do
        for _, key in ipairs({ "row", "template", "group", "tag", "name" }) do
            assert(type(recipe[key]) == "string" and recipe[key] ~= "", "missing recipe " .. key)
        end
        assert(recipe.row:lower() ~= recipe.template:lower(), "custom recipe must have a new row name")
        assert(not rows[recipe.row:lower()], "duplicate recipe row: " .. recipe.row)
        assert(not tags[recipe.tag:lower()], "duplicate recipe tag: " .. recipe.tag)
        validate_items(recipe.ingredients, "ingredients")
        validate_items(recipe.outputs, "outputs")
        rows[recipe.row:lower()], tags[recipe.tag:lower()] = true, true
    end
end

local function item_entries(items)
    local entries = {}
    for index, item in ipairs(items) do
        entries[index] = { ItemTag = { TagName = FName(item.tag) }, Quantity = item.quantity }
    end
    return entries
end

local function read_items(entries)
    local items = {}
    entries:ForEach(function(_, element)
        local entry = element:get()
        items[#items + 1] = { tag = entry.ItemTag.TagName:ToString(), quantity = entry.Quantity }
    end)
    return items
end

local function items_match(actual, expected)
    if #actual ~= #expected then
        return false
    end
    for index, item in ipairs(expected) do
        local entry = actual[index]
        if entry.ItemTag.TagName:ToString() ~= item.tag or entry.Quantity ~= item.quantity then
            return false
        end
    end
    return true
end

local function recipe_matches(row, definition, group_tag)
    return row.RecipyTag.TagName:ToString() == definition.tag
        and row.RecipyGroupTag.TagName:ToString() == group_tag
        and row.RecipyName:ToString() == definition.name
        and items_match(row.UsedComponents, definition.ingredients)
        and items_match(row.CreatedItems, definition.outputs)
end

local function group_handles(group, recipes, row_name, omit_match)
    local handles, found = {}, false
    group.ManufactoringRecipies:ForEach(function(_, element)
        local handle = element:get()
        local source = handle.DataTable
        local matches = source and source:IsValid() and source:GetAddress() == recipes:GetAddress()
            and handle.RowName:ToString() == row_name
        found = found or matches
        if not (matches and omit_match) then
            handles[#handles + 1] = { DataTable = source, RowName = handle.RowName }
        end
    end)
    return handles, found
end

local function add_group_link(group, recipes, row_name, handles)
    local updated = { table.unpack(handles) }
    updated[#updated + 1] = { DataTable = recipes, RowName = FName(row_name) }
    group.ManufactoringRecipies = updated
    local _, found = group_handles(group, recipes, row_name)
    assert(found, "group reference did not round-trip")
end

local function install_recipe(definition, recipes, tags, groups)
    local template = assert(recipes:FindRow(definition.template), "template row missing: " .. definition.template)
    local group = assert(groups:FindRow(definition.group), "Workshop group missing: " .. definition.group)
    local stock_tag = template.RecipyTag.TagName:ToString()
    local group_tag = template.RecipyGroupTag.TagName:ToString()
    assert(stock_tag:lower() ~= definition.tag:lower(), "custom tag matches template tag")
    local tag_template = tags:FindRow(stock_tag)

    local existing = recipes:FindRow(definition.row)
    local tag_row = tags:FindRow(definition.tag)
    local handles, linked = group_handles(group, recipes, definition.row)
    if existing and tag_row and linked and recipe_matches(existing, definition, group_tag) then
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
            ingredients = read_items(existing.UsedComponents),
            outputs = read_items(existing.CreatedItems),
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
        if not existing or not recipe_matches(existing, definition, group_tag) then
            changed_recipe = true
            if not existing then recipes:AddRow(definition.row, template) end
            local row = assert(recipes:FindRow(definition.row), "recipe row could not be read")
            row.UsedComponents = item_entries(definition.ingredients)
            row.CreatedItems = item_entries(definition.outputs)
            row.RecipyName = FText(definition.name)
            row.RecipyTag.TagName = FName(definition.tag)
            row.RecipyGroupTag.TagName = FName(group_tag)
            assert(recipe_matches(row, definition, group_tag), "recipe fields did not round-trip")
        end
        if not linked then
            changed_group = true
            add_group_link(group, recipes, definition.row, handles)
        end
    end)
    if not ok then
        if changed_group then group.ManufactoringRecipies = handles end
        if changed_recipe and previous then
            existing.UsedComponents = item_entries(previous.ingredients)
            existing.CreatedItems = item_entries(previous.outputs)
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

local function stock_recipes(recipes, groups)
    local stock, by_row = {}, {}
    recipes:ForEachRow(function(row_name, recipe)
        row_name = tostring(row_name)
        if row_name:match("^MCR_") then return end
        local record = {
            row = row_name,
            name = recipe.RecipyName:ToString(),
            tag = recipe.RecipyTag.TagName:ToString(),
            group_tag = recipe.RecipyGroupTag.TagName:ToString(),
            ingredients = read_items(recipe.UsedComponents),
            outputs = read_items(recipe.CreatedItems),
            groups = {},
        }
        by_row[row_name] = record
        stock[#stock + 1] = record
    end)
    groups:ForEachRow(function(row_name, group)
        group.ManufactoringRecipies:ForEach(function(_, element)
            local handle = element:get()
            local source = handle.DataTable
            local recipe = by_row[handle.RowName:ToString()]
            if recipe and source and source:IsValid() and source:GetAddress() == recipes:GetAddress() then
                recipe.groups[#recipe.groups + 1] = tostring(row_name)
            end
        end)
    end)
    table.sort(stock, function(a, b) return a.row < b.row end)
    for _, recipe in ipairs(stock) do table.sort(recipe.groups) end
    return stock
end

local function install_extra_group(definition, groups)
    local group = groups:FindRow(definition.row)
    local is_new = not group
    local template = assert(groups:FindRow(definition.template), "group template missing: " .. definition.template)
    local filter_tag = template.FilterTag.TagName:ToString()
    local label = FText(definition.name)
    local description = FText(definition.description)
    local ok, err = pcall(function()
        if is_new then
            groups:AddRow(definition.row, template)
            group = assert(groups:FindRow(definition.row), "group row could not be read")
            group.ManufactoringRecipies = {}
        end
        group.ManufactoringGroupName = label
        group.ManufactoringGroupSubtext = description
        group.ManufactoringGroupDetailsText = description
        group.FilterTag.TagName = FName(filter_tag)
        assert(group.ManufactoringGroupName:ToString() == definition.name, "group name did not round-trip")
        assert(group.FilterTag.TagName:ToString() == filter_tag, "group filter did not round-trip")
    end)
    if not ok then
        if is_new then groups:RemoveRow(definition.row) end
        error(err, 0)
    end
    return is_new
end

local function remove_old_group_link(groups, recipes, group_name, definition, log)
    if group_name == definition.group then return end
    local ok, err = pcall(function()
        local group = groups:FindRow(group_name)
        if not group then return end
        local handles, found = group_handles(group, recipes, definition.row, true)
        if found then group.ManufactoringRecipies = handles end
    end)
    if not ok then
        log("Could not remove old link for " .. definition.row .. " in " .. group_name .. ": " .. tostring(err))
    end
end

function M.install(config, log)
    local recipes, tags, groups = M.find_table("recipes"), M.find_table("tags"), M.find_table("groups")
    if not (recipes and tags and groups) then
        return false
    end
    local ok, definitions = pcall(function()
        local built = config.build(stock_recipes(recipes, groups), log)
        M.validate(built)
        return built
    end)
    if not ok then
        log("Could not build recipes: " .. tostring(definitions))
        return true, {}
    end
    local destinations = {}
    for _, group in ipairs(config.extra_groups or {}) do
        local ok, changed = pcall(install_extra_group, group, groups)
        if ok then
            destinations[#destinations + 1] = group
            if changed then log("Installed group " .. group.row) end
        else
            log("Could not install group " .. group.row .. ": " .. tostring(changed))
        end
    end

    for _, definition in ipairs(definitions) do
        local previous_group = definition.group
        for _, destination in ipairs(destinations) do
            if destination.includes(definition) then
                definition.group = destination.row
                break
            end
        end
        local ok, changed = pcall(install_recipe, definition, recipes, tags, groups)
        if not ok then
            log("Could not install " .. definition.row .. ": " .. tostring(changed))
        elseif changed then
            log("Installed " .. definition.row .. " in " .. definition.group)
        end
        if ok then
            remove_old_group_link(groups, recipes, previous_group, definition, log)
            for _, group in ipairs(destinations) do
                remove_old_group_link(groups, recipes, group.row, definition, log)
            end
        end
    end
    return true, definitions
end

return M
