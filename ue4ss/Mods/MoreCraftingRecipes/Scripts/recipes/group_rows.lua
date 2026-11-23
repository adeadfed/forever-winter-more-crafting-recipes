local M = {}

function M.handles(group, recipes, row_name, omit_match)
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

function M.link(group, recipes, row_name, handles)
    local updated = { table.unpack(handles) }
    updated[#updated + 1] = { DataTable = recipes, RowName = FName(row_name) }
    group.ManufactoringRecipies = updated
    local _, found = M.handles(group, recipes, row_name)
    assert(found, "group reference did not round-trip")
end

function M.install(definition, groups)
    local group = groups:FindRow(definition.row)
    local is_new = not group
    local template = assert(groups:FindRow(definition.template), "group template missing: " .. definition.template)
    local filter_template = template
    if definition.filter_template then
        filter_template = assert(groups:FindRow(definition.filter_template),
            "group filter template missing: " .. definition.filter_template)
    end
    local filter_tag = filter_template.FilterTag.TagName:ToString()
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

function M.unlink(groups, recipes, group_name, row, log)
    local ok, err = pcall(function()
        local group = groups:FindRow(group_name)
        if not group then return end
        local handles, found = M.handles(group, recipes, row, true)
        if found then group.ManufactoringRecipies = handles end
    end)
    if not ok then
        log("Could not unlink " .. row .. " in " .. group_name .. ": " .. tostring(err))
    end
end

return M
