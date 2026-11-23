local objects = require("books/game/objects")
local manuals = require("books/manuals")
local sessions = require("books/raid/session")
local valid, same = objects.valid, objects.same
local save_class = "/Game/FW/Components/BPC_PlayerSaveGames.BPC_PlayerSaveGames_C"
local M = {}

local function key(obj) return obj:GetFullName() .. "@" .. tostring(obj:GetAddress()) end
local function hub(name) return name:find("/Game/LevelDesign/HUB_World/", 1, true) ~= nil end

function M.start(progress, rates, refresh, log)
    local raid, owner, last_world, dead_world, local_pawn
    local game, system, save_type
    local awards, discarded, retry, hooks, installed = {}, {}, false, {}, {}
    local ready = false
    local function player(context)
        if not valid(context) or not valid(game) then return end
        local pc = game:GetPlayerController(context, 0)
        if valid(pc) and pc:IsLocalController() and valid(pc.Player) then return pc end
    end
    local function guarded(fn)
        return function(...)
            local ok, result = pcall(fn, ...)
            if ok then return result end
            log("Raid manuals: " .. tostring(result))
        end
    end

    local function notice(pc, message)
        local learned, total = progress.count()
        pc:ClientDisplayPlayerMessage(FText(message .. "\nUnlocked Manuals " .. learned .. "/" .. total))
    end

    local function report_awards(ids, pc)
        local titles = {}
        for _, family in ipairs(manuals.families) do
            for _, id in ipairs(family) do
                if ids[id] then titles[#titles + 1] = manuals.tiers[id].title end
            end
        end
        refresh()
        local message = "Crafting recipes unlocked\n" .. table.concat(titles, ", ")
        log(message:gsub("\n", " — "))
        if valid(pc) then notice(pc, message) end
    end

    local function save_results(pc)
        local err
        if next(discarded) then
            local ok, why = progress.finish_raid(discarded, false)
            if ok then discarded = {} else err = why end
        end
        if next(awards) then
            local ok, why = progress.finish_raid(awards, true)
            if ok then
                local saved = awards
                awards = {}
                report_awards(saved, pc)
            else err = why end
        end
        if err and not retry then
            retry = true
            log("Raid manual progress write failed. Retrying: " .. tostring(err))
            ExecuteInGameThreadWithDelay(5000, guarded(function()
                retry = false
                save_results()
            end))
        end
    end

    local function end_raid(result)
        if result then
            local held = {}
            for id in pairs(raid.held()) do
                if progress.raid_pending[id] then held[id], result[id] = true, true end
            end
            if result == discarded and next(held) then
                local recorded, err = progress.record_loss(held)
                if not recorded then log("Could not record raid loss: " .. tostring(err)) end
            end
        end
        raid, owner, local_pawn = nil, nil, nil
    end

    local function start_raid(pc, recover_only)
        local held = {}
        for id in pairs(progress.raid_pending) do
            if not awards[id] and not discarded[id] then held[id] = true end
        end
        if recover_only and not next(held) then return end
        raid = sessions.new(function(id) return progress.known(id) or awards[id] or discarded[id] end,
            rates, math.random, held, progress.stage_raid)
        owner = key(pc.Player)
    end

    local function visit(world, pc)
        if not valid(world) then return end
        local name, world_key = world:GetFullName(), key(world)
        if hub(name) then
            if not valid(pc) or not valid(pc.Pawn) or not same(pc:GetWorld(), world) then return end
            if raid then
                if owner ~= key(pc.Player) then return end
                if raid.arrive() then end_raid(awards)
                elseif raid.left_via_menu() then end_raid(discarded)
                else end_raid() end
            end
            dead_world, last_world, local_pawn = nil, world_key, nil
            save_results(pc)
        elseif last_world ~= world_key and name:find("/Game/FW/UI/MainMenu/", 1, true) then
            last_world, dead_world, local_pawn = world_key, nil, nil
            if raid then raid.menu() end
        elseif name:match("^World /Game/") and not name:find("/UI/", 1, true) then
            if last_world ~= world_key then
                last_world, dead_world, local_pawn = world_key, nil, nil
                if raid and not raid.field() then
                    end_raid(discarded)
                    save_results()
                end
            end
            if dead_world ~= world_key and valid(pc) and valid(pc.Player) and same(world, pc:GetWorld()) then
                if not raid and next(progress.raid_pending) then start_raid(pc, true) end
                if valid(pc.Pawn) and (not owner or owner == key(pc.Player)) then local_pawn = key(pc.Pawn) end
            end
        end
    end

    local function get_session(pc)
        if not ready then return end
        local world = pc:GetWorld()
        visit(world, pc)
        if not valid(world) or not valid(pc.Player) or key(world) == dead_world then return end
        local name = world:GetFullName()
        if hub(name) or not name:match("^World /Game/") or name:find("/UI/", 1, true) then return end
        if not raid then start_raid(pc, false) end
        if owner == key(pc.Player) then return raid end
    end

    local function current(pc)
        if not raid and next(progress.raid_pending) and valid(pc) and valid(pc.Player) then
            visit(pc:GetWorld(), pc)
        end
        return raid and valid(pc) and valid(pc.Player) and key(pc.Player) == owner
            and valid(pc:GetWorld()) and key(pc:GetWorld()) == last_world
    end

    local function hook(path, fn, after)
        hooks[#hooks + 1] = { path = path, callback = guarded(fn), after = after }
    end

    hook("/Script/FWSession.FWGameInstance:SetExtracted", function(ctx)
        if not raid and not next(progress.raid_pending) then return end
        local instance = ctx:get()
        local pc = player(instance)
        if not current(pc) then return end
        if valid(system) and system:IsStandalone(pc) and same(instance:GetWorld(), pc:GetWorld()) then
            raid.success(last_world)
        end
    end, true)
    hook("/Script/FWQuestSystem.FWQuestComponent:ClientOnPlayerExtracted", function(ctx, controller)
        if not raid and not next(progress.raid_pending) then return end
        local pc = player(ctx:get())
        if current(pc) and controller and same(pc, controller:get()) then raid.success(last_world) end
    end, true)
    hook(save_class .. ":ExtractLoot", function(ctx, checkpoint, transfer)
        if not raid and not next(progress.raid_pending) then return end
        local component = ctx:get()
        local pc = player(component)
        if not current(pc) or not valid(pc.PlayerState) then return end
        if valid(save_type) and same(component, pc.PlayerState:GetComponentByClass(save_type)) then
            raid.extract(last_world, checkpoint:get(), transfer:get())
        end
    end)

    local function died(ctx)
        if not raid and not next(progress.raid_pending) then return end
        local pawn = ctx:get()
        local pc = player(pawn)
        if not current(pc) then return end
        if not same(pawn, pc.Pawn) then
            -- The death callback can arrive after the controller releases its pawn.
            if valid(pc.Pawn) or not valid(pawn) or not same(pawn:GetWorld(), pc:GetWorld()) then return end
            if key(pawn) ~= local_pawn and not same(pawn.PlayerState, pc.PlayerState) then return end
        end
        dead_world = last_world
        end_raid(discarded)
        save_results()
        log("Local death discarded pending raid manuals.")
    end
    hook("/Script/FWGameCore.FWCharacter:OnSyncKilledDeath", died)
    hook("/Game/FW/Player/BP_PlayerBase.BP_PlayerBase_C:Tunnel Death Extract", died)
    hook("/Script/Engine.PlayerController:ClientRestart", function(ctx)
        local pc = ctx:get()
        if valid(pc) and pc:IsLocalController() and valid(pc.Player) then visit(pc:GetWorld(), pc) end
    end, true)

    local hide, restore_open
    if rates then
        hide, restore_open = require("books/raid/loot").bind(hook, get_session, function(pc, id)
            notice(pc, manuals.tiers[id].title .. " found\nExtract to Innards to unlock new crafting recipes.")
            log("Picked up " .. manuals.tiers[id].title .. " locally.")
        end, player)
    end
    local function bind()
        if not valid(game) then game = StaticFindObject("/Script/Engine.Default__GameplayStatics") end
        if not valid(system) then system = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary") end
        if not valid(save_type) then save_type = StaticFindObject(save_class) end
        local missing = false
        for _, h in ipairs(hooks) do
            if not installed[h.path] then
                if valid(StaticFindObject(h.path)) then
                    if h.after then RegisterHook(h.path, function() end, h.callback)
                    else RegisterHook(h.path, h.callback) end
                    installed[h.path] = true
                else missing = true end
            end
        end
        if missing or not valid(game) or not valid(system) or not valid(save_type) then
            ExecuteInGameThreadWithDelay(1000, guarded(bind))
        elseif not ready then
            ready = true
            local pc = player(require("UEHelpers").GetGameInstance())
            if pc then visit(pc:GetWorld(), pc) end
            if restore_open then restore_open(pc) end
        end
    end
    ExecuteInGameThread(guarded(bind))
    local travel = 0
    RegisterLoadMapPreHook(guarded(function()
        travel = travel + 1
        if hide then hide() end
    end))
    RegisterLoadMapPostHook(guarded(function(_, param)
        if not param then return end
        local world = param:get()
        if not valid(world) then return end
        if ready and (not valid(game) or not valid(system) or not valid(save_type)) then
            ready = false
            ExecuteInGameThread(guarded(bind))
        end
        if not hub(world:GetFullName()) then visit(world, player(world)); return end
        local arrival = travel
        local function in_innards()
            if travel ~= arrival or not raid or not valid(world) then return end
            local pc = player(world)
            if pc and same(pc:GetWorld(), world) and valid(pc.Pawn) then visit(world, pc)
            else ExecuteInGameThreadWithDelay(500, guarded(in_innards)) end
        end
        in_innards()
    end))
    log(rates and "Client-side raid manual drops enabled." or "Tracking saved raid manual pickups.")
end

return M
