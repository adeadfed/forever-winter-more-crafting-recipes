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

local function parse(content)
    local state = { unlocked = {}, pending = {} }
    local sections = { UnlockedManuals = state.unlocked, PendingPurchases = state.pending }
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
                local id, value = line:match("^([%w_]+)%s*=%s*(%a+)$")
                if not section or not id or (value ~= "true" and value ~= "false") then
                    return nil, "invalid entry in manuals.ini: " .. line
                end
                if manuals.tiers[id] then
                    if section[id] ~= nil then return nil, "duplicate manual entry: " .. id end
                    section[id] = value == "true"
                end
            end
        end
    end
    if not found_unlocked then return nil, "manuals.ini is missing [UnlockedManuals]" end
    return state
end

local function save(path, state, replace)
    local lines = { "[UnlockedManuals]" }
    local pending = {}
    for _, family in ipairs(manuals.families) do
        for _, id in ipairs(family) do
            lines[#lines + 1] = id .. " = " .. tostring(state.unlocked[id] == true)
            if state.pending[id] then pending[#pending + 1] = id .. " = true" end
        end
    end
    if #pending > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "[PendingPurchases]"
        for _, entry in ipairs(pending) do lines[#lines + 1] = entry end
    end

    local temporary, backup = path .. ".tmp", path .. ".bak"
    local file, err = io.open(temporary, "wb")
    if not file then return nil, err end
    local written, write_error = file:write(table.concat(lines, "\n") .. "\n")
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

local function load(directory)
    local path = directory .. "/manuals.ini"
    local content, err = read(path)
    if err then return nil, err end
    if content then
        local state, parse_error = parse(content)
        if not state then return nil, parse_error end
        return state, path
    end

    local backup = path .. ".bak"
    local previous, read_error = read(backup)
    if read_error then return nil, read_error end
    if previous then
        local state, parse_error = parse(previous)
        if not state then return nil, parse_error end
        local restored, restore_error = os.rename(backup, path)
        if not restored then return nil, restore_error end
        return state, path
    end

    local state = { unlocked = {}, pending = {} }
    local created, create_error = save(path, state, false)
    if not created then return nil, create_error end
    return state, path
end

function M.learned(directory)
    local state, err = load(directory)
    assert(state, err)
    for id in pairs(manuals.tiers) do
        state.unlocked[id] = state.unlocked[id] == true
    end
    return state.unlocked
end

function M.stage_purchase(directory, id)
    assert(manuals.tiers[id], "unknown manual")
    local state, path = load(directory)
    if not state then return nil, path end
    if state.pending[id] then return nil, "purchase receipt already exists" end
    if state.unlocked[id] then return nil, "manual already learned" end
    state.pending[id] = true
    return save(path, state, true)
end

function M.commit_purchase(directory, id)
    assert(manuals.tiers[id], "unknown manual")
    local state, path = load(directory)
    if not state then return nil, path end
    if not state.pending[id] then return nil, "purchase receipt unavailable" end
    state.unlocked[id], state.pending[id] = true, nil
    return save(path, state, true)
end

return M
