-- Run with Lua 5.4 from the repository root.
package.path = "ue4ss/Mods/MoreCraftingRecipes/Scripts/?.lua;" .. package.path
local sources = require("books/raid/sources")
local sessions = require("books/raid/session")
local manuals = require("books/manuals")
local function crate(family, tier)
    local name = ("BP_LootContainer_%s_T%d"):format(family, tier)
    return ("BlueprintGeneratedClass /Game/FW/LootObjects/Containers/EconV2/Parity/T%d/%s.%s_C"):format(tier, name, name)
end
local function tunnel(tier)
    return ("World /Game/FW/Maps/ProceduralTunnels/Dungeons/Tunnel%d/L_Dungeon_Tunnel%d_04.Level"):format(tier, tier)
end
local surface = "World /Game/FW/Maps/Test.Level"
local hub = "World /Game/LevelDesign/HUB_World/HUB.Level"
local menu = "World /Game/FW/UI/MainMenu/Levels/FW_MenuEmpty.Level"
local reachable = {}
for tier = 1, 4 do
    local sector = ("ABCD"):sub(tier, tier)
    for _, family in ipairs({"Army", "Armament", "Civilian", "Material", "Medical", "Provision"}) do
        local actual, pool = sources.container(crate(family, tier), surface)
        assert(actual == sector)
        assert(sources.container(crate(family, 1), tunnel(tier)) == sector)
        for _, id in ipairs(pool) do if sources.matches(id, sector) then reachable[id] = true end end
    end
end
for id in pairs(manuals.tiers) do assert(reachable[id], id .. " has no eligible world crate") end
assert(not sources.container(crate("Army", 1), hub))
local body = "/Game/FW/LootObjects/FromCorpses/BP_RandomLoot_Corpse_Cyborg.BP_RandomLoot_Corpse_Cyborg_C"
assert(not sources.container(body, tunnel(1)))
assert(not sources.container("/Game/FW/LootObjects/Containers/BP_DroppedBag.BP_DroppedBag_C", surface))
assert(not sources.container("/Game/Other/BP_LootContainer_Army_T1.BP_LootContainer_Army_T1_C", surface))

local rolls = 0
local function deterministic(n)
    if n then return 1 end
    rolls = rolls + 1
    return 0.019
end
local known = { IFF = true }
local rates = { A = 2, B = 1.5, C = 0, D = 100 }
local function new() return sessions.new(function(id) return known[id] end, rates, deterministic, {}, function() return true end) end
local session, peer = new(), new()
local pool = { "IFF", "WORKSHOP_A", "ELECTRONICS_A" }
assert(session.offer("one", "A", pool) == "WORKSHOP_A")
assert(session.offer("one", "A", pool) == "WORKSHOP_A" and rolls == 1)
assert(session.offer("two", "A", pool) == "ELECTRONICS_A")
assert(peer.offer("one", "A", pool) == "WORKSHOP_A")
assert(not session.take("two", "WORKSHOP_A"))
assert(session.take("one", "WORKSHOP_A") and not session.take("one", "WORKSHOP_A"))
assert(not session.offer("one", "A", pool))
assert(not session.offer("three", "A", pool))
assert(not session.offer("miss", "B", {"RIG_B"}))
local misses = rolls
assert(not session.offer("miss", "B", {"RIG_B"}) and rolls == misses)
assert(not session.offer("off", "C", {"RIG_C"}) and rolls == misses)
assert(session.take("two", "ELECTRONICS_A"))
session.success("world")
session.extract("world", true, false)
assert(not session.arrive())
session.menu()
assert(session.field())
session.success("world")
session.extract("world", false, true)
assert(not session.arrive() and session.field())
session.extract("new-world", false, false)
session.success("other-world")
assert(not session.arrive())
session.success("new-world")
assert(session.arrive().WORKSHOP_A and session.arrive().ELECTRONICS_A)
local abandoned = new()
abandoned.menu()
assert(abandoned.left_via_menu() and not abandoned.field())

-- Exercise the production loot and travel hooks with independent local and remote controllers.
local function object(name)
    return { IsValid = function() return true end, GetAddress = function() return name end,
        GetFullName = function() return name end, GetFName = function() return {ToString=function() return name end} end }
end
local function param(value) return {get = function() return value end} end
local callbacks, delays, registered, claims = {}, {}, {}, {}
local pc, remote, ui = object("controller"), object("remote"), object("ui")
local world = object(tunnel(1))
pc.Player, pc.Pawn, pc.PlayerState = object("local player"), object("pawn"), object("state")
pc.Pawn.LootUI, pc.IsLocalController, pc.GetWorld = ui, function() return true end, function() return world end
pc.Pawn.GetWorld, remote.GetWorld = pc.GetWorld, pc.GetWorld
pc.ClientDisplayPlayerMessage = function(_, msg) claims[#claims + 1] = msg end
local saves = object("local save")
pc.PlayerState.GetComponentByClass = function() return saves end
ui.GetOwningPlayer, ui.IsVisible = function() return pc end, function() return true end
ui.LootItems = object("grid")
ui.LootItems.AddChildToWrapBox = function(self, wrap) wrap.parent = self end
local game = { IsValid = function() return true end, GetPlayerController = function() return pc end }
local standalone = false
local loot_class_loaded = true
local system = { IsValid = function() return true end, IsStandalone = function() return standalone end }
function StaticFindObject(path)
    if not loot_class_loaded and path:match(":GetLootToolTipWidget$") then return nil end
    if path:match("GameplayStatics$") then return game end
    if path:match("KismetSystemLibrary$") then return system end
    return object(path)
end
function RegisterHook(path, pre, post) assert(not callbacks[path]); callbacks[path] = post or pre end
function ExecuteInGameThread(fn) fn() end
function ExecuteInGameThreadWithDelay(ms, fn) delays[#delays+1] = {ms,fn} end
function RegisterLoadMapPreHook(fn) registered.before = fn end
function RegisterLoadMapPostHook(fn) registered.after = fn end
function FText(s) return s end
package.loaded.UEHelpers = {GetGameInstance = function() return nil end}
local function event(path, ...) assert(callbacks[path], path)(...) end
local function travel(name)
    registered.before()
    world = object(name)
    registered.after(nil, param(world))
end
local view
local tiles = {}
function tiles.clear_stale() end
function tiles.attach(panel, player, id)
    assert(player == pc and panel == ui)
    local wrapper = object("wrapper")
    wrapper.parent, wrapper.GetParent = ui.LootItems, function(self) return self.parent end
    view = {wrapper=wrapper, receiver=object("private receiver"), tile=object("manual tile"), id=id}
    view.tile.LootButton = {HasUserFocus=function() return false end}
    return view
end
function tiles.detach(old) if old then old.wrapper.parent = nil end end
package.loaded["books/raid/tile"] = tiles
local owner_save = "/Game/FW/Components/BPC_PlayerSaveGames.BPC_PlayerSaveGames_C:ExtractLoot"
local quest = "/Script/FWQuestSystem.FWQuestComponent:ClientOnPlayerExtracted"
local game_success = "/Script/FWSession.FWGameInstance:SetExtracted"
local death = "/Script/FWGameCore.FWCharacter:OnSyncKilledDeath"
local panel = "/Game/Widgets/Inventory/W_LootUI.W_LootUI_C:"
local button = "/Game/Widgets/Inventory/W_LootItem.W_LootItem_C:BndEvt__W_LootItem_LootButton_K2Node_ComponentBoundEvent_"
local remove = "/Script/UMG.Widget:RemoveFromParent"
local learned, pending, writes, refreshes, fail = {}, {}, 0, 0, false
local logs = {}
local store, directory = require("books/store"), arg and arg[1]
local fail_take = false
if directory then
    for _, name in ipairs({"manuals.ini", "manuals.recovery"}) do
        for _, suffix in ipairs({"", ".bak", ".tmp"}) do
            assert(not io.open(directory .. "/" .. name .. suffix, "rb"), "use a fresh test directory")
        end
    end
    assert(store.stage_purchase(directory, "WORKSHOP_D", 700000, 600000))
end
local find_object = StaticFindObject
local function start(drops_disabled)
    if directory then learned, pending = store.learned(directory) end
    local progress = { known=function(id) return learned[id] end, count=function() return 0, 15 end, raid_pending=pending }
    function progress.record_loss(ids)
        if directory then return store.record_outcome(directory, "lost", ids) end
        return true
    end
    function progress.stage_raid(id)
        if fail_take then return nil, "fixture pickup write failure" end
        if directory then assert(store.stage_raid(directory, id)) end
        pending[id] = true
        return true
    end
    function progress.finish_raid(ids, extracted)
        if extracted then writes = writes + 1 end
        if fail then return nil, "fixture write failure" end
        if directory then assert(store.finish_raid(directory, ids, extracted)) end
        for id in pairs(ids) do
            pending[id] = nil
            if extracted then learned[id] = true end
        end
        return true
    end
    StaticFindObject = find_object
    local drop_rates = not drops_disabled and {A=100,B=100,C=100,D=100}
    require("books/raid/runtime").start(progress, drop_rates,
        function() refreshes = refreshes + 1 end, function(s) logs[#logs+1] = s end)
    StaticFindObject = function(path) error("global object lookup in active callback: " .. path) end
end
local function restart(name, drops_disabled)
    callbacks, delays, registered = {}, {}, {}
    ui.LootContainerReference, world = nil, object(name)
    pc.Player = object("local player after restart")
    start(drops_disabled)
end
local function saved_state()
    if directory then return store.learned(directory) end
    return learned, pending
end
start()
local function open(name, asset)
    local box, cls = object(name), object(asset)
    cls.GetSuperStruct = function() return nil end
    box.GetClass, box.GetWorld = function() return cls end, function() return world end
    ui.LootContainerReference = box
    event(panel .. "PopulateLootItems", param(ui))
end
local function click()
    event(button .. "1_OnButtonPressedEvent__DelegateSignature", param(view.tile))
    event(remove, param(view.receiver))
end
local function extract(checkpoint, transfer, component)
    event(owner_save, param(component or saves), param(checkpoint), param(transfer))
end
open("body", body)
assert(not view)
open("crate1", crate("Provision", 1))
assert(view.id == "PROVISIONS")
assert(not next(pending), "showing an offer must not stage it")
ui.LootingAll = true
click()
assert(#claims == 0)
ui.LootingAll = false
fail_take = true; click(); fail_take = false
assert(#claims == 1 and claims[1]:find("retry") and not next(pending))
click(); click()
assert(#claims == 2 and writes == 0)
local unlocked, held = saved_state()
assert(held.PROVISIONS and not unlocked.PROVISIONS)
extract(true, false); travel(menu); travel(surface)
open("crate2", crate("Material", 1))
local second = view.id
click()
restart(menu); travel(hub)
unlocked, held = saved_state()
assert(held.PROVISIONS and held[second] and not unlocked.PROVISIONS and not unlocked[second] and writes == 0)
travel(tunnel(1))
event(quest, param(pc), param(remote))
extract(false, true); travel(surface)
event(death, param(remote))
extract(false, false, object("remote save"))
event(quest, param(pc), param(pc))
assert(writes == 0)
extract(false, false); fail = true
travel(hub)
assert(writes == 1 and not learned.PROVISIONS and refreshes == 0)
fail = false
for _, d in ipairs(delays) do if d[1] == 5000 then d[2]() end end
assert(writes == 2 and learned.PROVISIONS and learned[second] and refreshes == 1)
unlocked, held = saved_state()
assert(unlocked[second] and unlocked.PROVISIONS and not next(held))
travel(hub)
assert(writes == 2)
local instance = object("instance")
instance.GetWorld = function() return world end
local function acquire_next()
    travel(tunnel(2)); open("test box", crate("Army", 2)); click()
end
acquire_next()
event(game_success, param(instance)); event(quest, param(pc), param(remote)); extract(false,false); travel(hub)
assert(writes == 2, "remote success must not award the guest")
acquire_next()
local lost = view.id
loot_class_loaded = false
restart(tunnel(2))
event(death, param(remote))
assert(pending[lost], "remote death must keep recovered finds")
-- Death may be the first local callback after a cold start, before opening a crate.
local dead_pawn = pc.Pawn
dead_pawn.PlayerState, pc.Pawn = pc.PlayerState, nil
event(death, param(remote))
assert(pending[lost], "another pawn dying after local unpossession must keep pending manuals")
event(death, param(dead_pawn))
pc.Pawn = dead_pawn
unlocked, held = saved_state()
assert(not next(held) and not unlocked[lost] and unlocked.PROVISIONS)
loot_class_loaded = true
restart(tunnel(2))
event(quest, param(pc), param(pc)); extract(false,false); travel(hub)
assert(writes == 2, "death must discard pending manuals")
acquire_next()
travel(menu); travel(hub)
assert(writes == 2 and not next(pending), "abandonment must discard pending manuals")
acquire_next()
standalone = true
event(game_success, param(instance)); extract(false,false); travel(hub)
assert(writes == 3 and refreshes == 2)
travel(tunnel(3)); open("tier three", crate("Army", 3)); click()
local failed_discard = view.id
assert(pending[failed_discard])
fail = true
restart(tunnel(3), true)
assert(not callbacks[panel .. "PopulateLootItems"], "disabling new drops must keep only the recovery hooks")
event(death, param(pc.Pawn))
event(quest, param(pc), param(pc)); extract(false, false); travel(hub)
assert(not learned[failed_discard], "a failed discard must not turn into a grant")
fail = false
if directory then
    -- Restart before the retry, then attempt to extract the lost tier on a later raid.
    restart(tunnel(3), true)
    event(quest, param(pc), param(pc)); extract(false, false); travel(hub)
else
    for _, d in ipairs(delays) do if d[1] == 5000 then d[2]() end end
end
restart(hub)
assert(not pending[failed_discard] and not learned[failed_discard], "a discard retry must survive restart")
for _, line in ipairs(logs) do
    assert(not line:match("^Raid manuals:") or line:find("fixture pickup write failure", 1, true), line)
end
if directory then
    assert(store.commit_purchase(directory, "WORKSHOP_D"), "purchase receipt was lost")
    local definitions = {}
    for id in pairs(manuals.tiers) do definitions[#definitions + 1] = {row=id, manual=id} end
    local function load_progress() return require("books/progression").new(directory, definitions, {}) end
    local progress = load_progress()
    assert(progress.known("WORKSHOP_D") and progress.stage_raid(failed_discard))
    progress = load_progress()
    assert(progress.raid_pending[failed_discard] and not progress.visibility()[failed_discard])
    assert(progress.finish_raid({[failed_discard]=true}, false))
    progress = load_progress()
    assert(not progress.raid_pending[failed_discard] and not progress.known(failed_discard))
    assert(not progress.finish_raid({[failed_discard]=true}, true), "uncollected manuals cannot be learned")
    assert(progress.stage_raid(failed_discard))
    assert(progress.finish_raid({[failed_discard]=true}, true))
    progress = load_progress()
    assert(progress.visibility()[failed_discard] and not progress.raid_pending[failed_discard])
end
local installer = require("core/installer")
local function data(name, path)
    local t = object(name)
    t.GetFullName = function() return "DataTable " .. path .. "." .. name end
    return t
end
local group_name = "DT_ManufactoringGroups"
assert(not installer.is_group_table(data("Other", "/Game/Other")))
assert(not installer.is_group_table(data(group_name, "/Game/Other/" .. group_name)))
assert(installer.is_group_table(data(group_name, "/Game/FW/UI/Manufactoring/Data/" .. group_name)))
print("Passed raid manual assignments, chances, pickup, travel, ownership and persistence retry tests.")
