local manuals = require("books/manuals")
local store = require("books/store")

local M = {}

function M.new(folder, definitions, overrides)
    local learned, raid_pending = store.learned(folder)
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
        known = function(id) return learned[id] == true end,
        raid_pending = raid_pending,
        record_loss = function(ids) return store.record_outcome(folder, "lost", ids) end,
        stage_raid = function(id)
            local ok, err = store.stage_raid(folder, id)
            if ok then raid_pending[id] = true end
            return ok, err
        end,
        count = function()
            local known, total = 0, 0
            for id in pairs(manuals.tiers) do
                total = total + 1
                if learned[id] then known = known + 1 end
            end
            return known, total
        end,
        finish_raid = function(ids, extracted)
            local ok, err = store.finish_raid(folder, ids, extracted)
            if not ok then return nil, err end
            for id in pairs(ids) do
                raid_pending[id] = nil
                if extracted then learned[id], prices[id] = true, nil end
            end
            return true
        end,
        learn = function(id)
            learned[id] = true
            prices[id], raid_pending[id] = nil, nil
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
