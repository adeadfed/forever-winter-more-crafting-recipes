local M = {}
local row_type = "/Script/FWHubWorld.ManufactoringRecipies"
local time_offset = 0x68
local registered = false

local function crafting_ticks(row)
    local value = row.RecipyCraftTime
    if type(value) ~= "number" and not registered then
        assert(value:GetStructAddress() - row:GetStructAddress() == time_offset,
            "Manufacturing craft-time layout differs from the supported layout")
        RegisterCustomProperty({
            BelongsToClass = row_type,
            Name = "RecipyCraftTime",
            OffsetInternal = time_offset,
            Type = PropertyTypes.UInt64Property,
        })
        registered = true
        value = row.RecipyCraftTime
    end
    assert(type(value) == "number", "Could not read crafting time")
    return value
end

function M.apply(recipes)
    local changed = 0
    recipes:ForEachRow(function(_, row)
        if crafting_ticks(row) ~= 0 then
            row.RecipyCraftTime = 0
            assert(row.RecipyCraftTime == 0, "Could not set crafting time to zero")
            changed = changed + 1
        end
    end)
    return changed
end

return M
