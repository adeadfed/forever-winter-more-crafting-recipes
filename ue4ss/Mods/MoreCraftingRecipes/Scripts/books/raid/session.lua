local sources = require("books/raid/sources")
local M = {}

function M.new(known, rates, random, pending, stage)
    local rolled, reserved = {}, {}
    local success, destination, checkpoint, in_menu
    local session = {}

    function session.offer(crate, sector, pool)
        if rolled[crate] ~= nil then
            local id = rolled[crate]
            if id and reserved[id] == crate and not known(id) then return id end
            return
        end
        rolled[crate] = false
        local candidates = {}
        for _, id in ipairs(pool) do
            if sources.matches(id, sector) and not known(id) and not pending[id] and not reserved[id] then
                candidates[#candidates + 1] = id
            end
        end
        if #candidates == 0 or rates[sector] <= 0 or random() * 100 >= rates[sector] then return end
        local id = candidates[random(#candidates)]
        rolled[crate], reserved[id] = id, crate
        return id
    end

    function session.take(crate, id)
        if not id or reserved[id] ~= crate or rolled[crate] ~= id or known(id) then return false end
        local saved, err = stage(id)
        if not saved then return false, err end
        reserved[id], pending[id] = nil, true
        return true
    end

    function session.success(world) success = world end

    function session.extract(world, is_checkpoint, to_tunnel)
        if is_checkpoint == true then
            checkpoint, in_menu = true, false
        elseif is_checkpoint == false and to_tunnel == false then
            checkpoint, in_menu = nil, nil
            destination = world
            return
        else
            checkpoint, in_menu = nil, nil
        end
        success, destination = nil, nil
    end

    function session.menu()
        in_menu = true
        success, destination = nil, nil
    end

    function session.left_via_menu() return in_menu == true end
    function session.held() return pending end

    function session.field()
        local resumed = not in_menu or checkpoint == true
        success, destination, checkpoint, in_menu = nil, nil, nil, nil
        return resumed
    end

    function session.arrive()
        if success and success == destination and next(pending) then return pending end
    end

    return session
end

return M
