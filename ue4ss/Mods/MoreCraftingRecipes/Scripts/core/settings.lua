local M = {}

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local flags = {
    crafting = { instant = "instant" },
    recipebooks = { enabled = "books_enabled", raiddrops = "raid_drops" },
}
local booleans = { ["true"] = true, ["false"] = false }

function M.read(path, log)
    local settings = {
        instant = false,
        books_enabled = true,
        raid_drops = false,
        drop_rates = { A = 4, B = 3, C = 2, D = 1 },
        book_prices = {},
    }
    local file, err = io.open(path, "r")
    if not file then
        log("Using default settings: " .. tostring(err))
        return settings
    end

    local section, line_number = "", 0
    for line in file:lines() do
        line_number = line_number + 1
        line = trim(line:gsub("^\239\187\191", ""):gsub("[;#].*$", ""))
        if line ~= "" then
            local header = line:match("^%[([^%]]+)%]$")
            if header then
                section = trim(header):lower()
            else
                local key, value = line:match("^([%w_]+)%s*=%s*(.-)$")
                key = key and key:lower()
                local valid = false
                local field = flags[section] and flags[section][key]
                if field then
                    local parsed = booleans[value:lower()]
                    valid = parsed ~= nil
                    if valid then settings[field] = parsed end
                elseif section == "raiddropchances" and key then
                    local sector = key:upper()
                    local rate = value:match("^%d+%.?%d*$") and tonumber(value)
                    valid = settings.drop_rates[sector] ~= nil and rate ~= nil and rate >= 0 and rate <= 100
                    if valid then settings.drop_rates[sector] = rate end
                elseif section == "recipebookprices" and key then
                    local tier = key:upper()
                    local price = value:match("^%d+$") and tonumber(value)
                    valid = require("books/manuals").tiers[tier] ~= nil
                        and math.type(price) == "integer" and price > 0 and price <= 2147483647
                    if valid then settings.book_prices[tier] = price end
                end
                if not valid then
                    log("Ignored invalid setting on INI line " .. line_number)
                end
            end
        end
    end
    file:close()
    return settings
end

return M
