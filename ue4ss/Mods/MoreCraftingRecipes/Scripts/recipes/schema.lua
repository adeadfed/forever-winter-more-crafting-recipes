local M = {}

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

function M.item_entries(items)
    local entries = {}
    for index, item in ipairs(items) do
        entries[index] = { ItemTag = { TagName = FName(item.tag) }, Quantity = item.quantity }
    end
    return entries
end

function M.read_items(entries)
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

function M.matches(row, definition, group_tag)
    return row.RecipyTag.TagName:ToString() == definition.tag
        and row.RecipyGroupTag.TagName:ToString() == group_tag
        and row.RecipyName:ToString() == definition.name
        and items_match(row.UsedComponents, definition.ingredients)
        and items_match(row.CreatedItems, definition.outputs)
end

return M
