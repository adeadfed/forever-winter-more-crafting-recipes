local manuals = require("books/manuals")

local M = {}

local function read(path)
    local file, err, code = io.open(path, "rb")
    if not file then
        if code == 2 then return nil end
        return nil, err
    end
    local content, read_error = file:read("a")
    local closed, close_error = file:close()
    if read_error or not closed then return nil, read_error or close_error end
    return content
end

local function empty_state()
    return { unlocked = {}, purchases = {}, raid = {} }
end

local function parse(content)
    local state = empty_state()
    local sections = { UnlockedManuals = state.unlocked, PendingPurchases = state.purchases, PendingRaidManuals = state.raid }
    local section, found_unlocked
    for raw in content:gsub("^\239\187\191", ""):gmatch("[^\r\n]+") do
        local line = raw:gsub("[;#].*$", ""):match("^%s*(.-)%s*$")
        if line ~= "" then
            local header = line:match("^%[([^%]]+)%]$")
            if header then
                section = sections[header]
                if not section then return nil, "unknown section in manuals.ini: " .. header end
                if section == state.unlocked then found_unlocked = true end
            else
                local id, value = line:match("^([%w_]+)%s*=%s*(.-)$")
                if not section or not id then
                    return nil, "invalid entry in manuals.ini: " .. line
                end
                local parsed
                if value == "true" or value == "false" then parsed = value == "true"
                elseif section == state.purchases then
                    local before, price = value:match("^(%d+) (%d+)$")
                    before, price = tonumber(before), tonumber(price)
                    if math.type(before) == "integer" and math.type(price) == "integer" and price > 0 and before >= price then
                        parsed = { before = before, price = price }
                    end
                end
                if parsed == nil then return nil, "invalid entry in manuals.ini: " .. line end
                if manuals.tiers[id] then
                    if section[id] ~= nil then return nil, "duplicate manual entry: " .. id end
                    section[id] = parsed
                end
            end
        end
    end
    if not found_unlocked then return nil, "manuals.ini is missing [UnlockedManuals]" end
    return state
end

local function write_file(path, content, replace)
    local temporary, backup = path .. ".tmp", path .. ".bak"
    local file, err = io.open(temporary, "wb")
    if not file then return nil, err end
    local written, write_error = file:write(content)
    local closed, close_error = file:close()
    if not written or not closed then return nil, write_error or close_error end

    -- Move the current file aside so Windows can rename the replacement.
    if replace then
        local removed, remove_error, code = os.remove(backup)
        if not removed and code ~= 2 then return nil, remove_error end
        local moved, move_error = os.rename(path, backup)
        if not moved then return nil, move_error end
    end
    local published, publish_error = os.rename(temporary, path)
    if not published then
        if replace then os.rename(backup, path) end
        return nil, publish_error
    end
    if replace then os.remove(backup) end
    return true
end

local function save(path, state, replace)
    local lines = { "[UnlockedManuals]" }
    for _, family in ipairs(manuals.families) do
        for _, id in ipairs(family) do
            lines[#lines + 1] = id .. " = " .. tostring(state.unlocked[id] == true)
        end
    end
    local function append_pending(header, ids)
        local first = true
        for _, family in ipairs(manuals.families) do
            for _, id in ipairs(family) do
                if ids[id] then
                    if first then
                        lines[#lines + 1] = ""
                        lines[#lines + 1] = header
                        first = false
                    end
                    local receipt = ids[id]
                    local value = type(receipt) == "table" and ("%d %d"):format(receipt.before, receipt.price) or "true"
                    lines[#lines + 1] = id .. " = " .. value
                end
            end
        end
    end
    append_pending("[PendingPurchases]", state.purchases)
    append_pending("[PendingRaidManuals]", state.raid)

    return write_file(path, table.concat(lines, "\n") .. "\n", replace)
end

local function read_file(path)
    local content, err = read(path)
    if content or err then return content, err end
    local backup = path .. ".bak"
    local previous, read_error = read(backup)
    if not previous then return nil, read_error end
    local restored, restore_error = os.rename(backup, path)
    if not restored then return nil, restore_error end
    return previous
end

local function load_state(directory)
    local path = directory .. "/manuals.ini"
    local content, err = read_file(path)
    if err then return nil, err end
    if content then
        local state, parse_error = parse(content)
        if not state then return nil, parse_error end
        return state, path
    end
    local state = empty_state()
    local created, create_error = save(path, state, false)
    if not created then return nil, create_error end
    return state, path
end

-- The native wallet and death callbacks cannot be replayed after a restart.
-- Keep their decisions until the replacement manuals.ini is on disk.
function M.record_outcome(directory, action, ids)
    assert(action == "paid" or action == "lost" or action == "declined", "unknown manual outcome")
    local record = { action }
    for id in pairs(ids) do
        assert(manuals.tiers[id], "unknown manual")
        record[#record + 1] = id
    end
    if #record == 1 then return true end
    local journal = directory .. "/manuals.recovery"
    local previous, err = read_file(journal)
    if err then return nil, err end
    return write_file(journal, (previous or "") .. table.concat(record, " ") .. "\n", previous ~= nil)
end

local function load(directory, read_only)
    local state, path = load_state(directory)
    if not state then return nil, path end
    local journal = directory .. "/manuals.recovery"
    local records, err = read_file(journal)
    if not records then
        if err then return nil, err end
        return state, path
    end
    local changed = false
    for line in records:gmatch("[^\r\n]+") do
        local action, ids = line:match("^(%a+) (.+)$")
        if action ~= "paid" and action ~= "lost" and action ~= "declined" then return nil, "invalid manual recovery record" end
        for id in ids:gmatch("%S+") do
            if not manuals.tiers[id] then return nil, "unknown manual in recovery record: " .. id end
            if action == "paid" and state.purchases[id] then
                state.unlocked[id], state.purchases[id], state.raid[id] = true, nil, nil
                changed = true
            elseif action == "lost" and state.raid[id] then
                state.raid[id], changed = nil, true
            elseif action == "declined" and state.purchases[id] then
                state.purchases[id], changed = nil, true
            end
        end
    end
    if changed then
        local ok, why = save(path, state, true)
        if not ok then
            if read_only then return state, path end
            return nil, why
        end
    end
    local cleared, clear_error, code = os.remove(journal .. ".bak")
    if not cleared and code ~= 2 then
        if read_only then return state, path end
        return nil, clear_error
    end
    local removed, why = os.remove(journal)
    if not removed and not read_only then return nil, why end
    return state, path
end

function M.learned(directory)
    local state, err = load(directory, true)
    assert(state, err)
    for id in pairs(manuals.tiers) do
        state.unlocked[id] = state.unlocked[id] == true
        if state.unlocked[id] or not state.raid[id] then state.raid[id] = nil end
    end
    return state.unlocked, state.raid, state.purchases
end

function M.stage_purchase(directory, id, before, price)
    assert(manuals.tiers[id], "unknown manual")
    assert(math.type(before) == "integer" and math.type(price) == "integer" and price > 0 and before >= price,
        "invalid manual purchase")
    local state, path = load(directory)
    if not state then return nil, path end
    if state.purchases[id] then return nil, "purchase receipt already exists" end
    if state.unlocked[id] then return nil, "manual already learned" end
    state.purchases[id] = { before = before, price = price }
    return save(path, state, true)
end

function M.commit_purchase(directory, id)
    assert(manuals.tiers[id], "unknown manual")
    local state, path = load(directory)
    if not state then return nil, path end
    if state.unlocked[id] then return true end
    if not state.purchases[id] then return nil, "purchase receipt unavailable" end
    state.unlocked[id], state.purchases[id], state.raid[id] = true, nil, nil
    return save(path, state, true)
end

function M.cancel_purchase(directory, id)
    -- A declined debit must not become a paid receipt if replacing the INI fails.
    M.record_outcome(directory, "declined", { [id] = true })
    local state, path = load(directory)
    if not state then return nil, path end
    if not state.purchases[id] then return true end
    state.purchases[id] = nil
    return save(path, state, true)
end

function M.stage_raid(directory, id)
    assert(manuals.tiers[id], "unknown raid manual")
    local state, path = load(directory)
    if not state then return nil, path end
    if state.unlocked[id] then return nil, "manual already learned" end
    if state.raid[id] then return true end
    state.raid[id] = true
    return save(path, state, true)
end

function M.finish_raid(directory, ids, extracted)
    local state, path = load(directory)
    if not state then return nil, path end
    local changed = false
    for id in pairs(ids) do
        assert(manuals.tiers[id], "unknown raid manual")
        if state.raid[id] then
            state.raid[id], changed = nil, true
            if extracted then state.unlocked[id] = true end
        elseif extracted and not state.unlocked[id] then
            return nil, "missing raid pickup for " .. id
        end
    end
    if changed then return save(path, state, true) end
    return true
end

return M
