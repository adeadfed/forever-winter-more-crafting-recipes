local manuals = require("books/manuals")
local store = require("books/store")

local M = {}

function M.new(folder, definitions, overrides)
    local learned = store.learned(folder)
    local used, base_prices = {}, {}
    for id, manual in pairs(manuals.tiers) do
        base_prices[id] = overrides[id] or manual.price
    end
    for _, recipe in ipairs(definitions) do
        assert(manuals.tiers[recipe.manual], "unknown manual for " .. recipe.row .. ": " .. tostring(recipe.manual))
        used[recipe.manual] = true
    end
    for id in pairs(manuals.tiers) do
        assert(used[id], "manual has no recipes: " .. id)
    end

    local prices = {}
    return {
        eligible = function(rows)
            prices = {}
            for _, recipe in ipairs(definitions) do
                local id = recipe.manual
                if rows[recipe.row] and not learned[id] then
                    prices[id] = base_prices[id]
                end
            end
        end,
        prices = function() return prices end,
        learn = function(id)
            learned[id] = true
            prices[id] = nil
        end,
        visibility = function()
            local visible = {}
            for _, recipe in ipairs(definitions) do
                visible[recipe.row] = learned[recipe.manual] == true
            end
            return visible
        end,
    }
end

return M
