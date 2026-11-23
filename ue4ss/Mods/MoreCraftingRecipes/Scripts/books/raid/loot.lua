local objects = require("books/game/objects")
local manuals = require("books/manuals")
local sources = require("books/raid/sources")
local tiles = require("books/raid/tile")
local valid, same = objects.valid, objects.same
local panel = "/Game/Widgets/Inventory/W_LootUI.W_LootUI_C:"
local tile = "/Game/Widgets/Inventory/W_LootItem.W_LootItem_C:"
local button = tile .. "BndEvt__W_LootItem_LootButton_K2Node_ComponentBoundEvent_"
local M = {}

function M.bind(hook, get_session, found, local_player)
    local view, press
    local crate_keys = {}
    local last_panel
    local function hide()
        local old = view
        view, press = nil, nil
        tiles.detach(old)
    end

    local function owner(ui)
        if not valid(ui) then return end
        local pc = ui:GetOwningPlayer()
        if not valid(pc) then pc = local_player(ui) end
        if valid(pc) and pc:IsLocalController() and valid(pc.Pawn) and same(pc.Pawn.LootUI, ui) then return pc end
    end

    local function active(object, field)
        if not view or not same(object, view[field]) then return end
        local ui = view.panel
        local pc = owner(ui)
        if pc and ui:IsVisible() and same(ui.LootContainerReference, view.crate)
            and same(view.wrapper:GetParent(), ui.LootItems) then return pc end
    end

    local function present(ui)
        local pc = owner(ui)
        if not pc then return end
        local crate, world = ui.LootContainerReference, pc:GetWorld()
        if view and (not same(view.panel, ui) or not same(view.crate, crate)) then hide() end
        if ui:GetAddress() ~= last_panel and valid(ui.LootItems) then
            tiles.clear_stale(ui.LootItems)
            last_panel = ui:GetAddress()
        end
        if not valid(crate) or not same(crate:GetWorld(), world) then return end
        local world_name = world:GetFullName()
        local sector, pool = sources.container(crate:GetClass():GetFullName(), world_name)
        if not sector then return end
        local session = get_session(pc)
        if not session then return end
        local path = crate:GetFullName()
        local key = crate_keys[path]
        if not key then
            -- A checkpoint can respawn a procedural crate with a new generated actor name.
            key = path
            if path:match("_%d%d%d%d%d%d%d%d%d%d$") then
                local ok, p = pcall(function() return crate:K2_GetActorLocation() end)
                if ok and p and type(p.X) == "number" and type(p.Y) == "number" and type(p.Z) == "number" then
                    key = ("%s/%s@%.0f,%.0f,%.0f"):format(world_name, crate:GetClass():GetFName():ToString(), p.X, p.Y, p.Z)
                end
            end
            crate_keys[path] = key
        end
        local id = session.offer(key, sector, pool)
        if not id then hide(); return end
        if view and view.session == session and view.id == id and valid(view.wrapper) then
            if not same(view.wrapper:GetParent(), ui.LootItems) then ui.LootItems:AddChildToWrapBox(view.wrapper) end
            return
        end
        hide()
        local created = tiles.attach(ui, pc, id, manuals.tiers[id])
        created.panel, created.crate, created.key = ui, crate, key
        created.session, created.id = session, id
        view = created
    end

    local function take(obj, field)
        local pc = active(obj, field)
        if not pc or view.panel.LootingAll then return end
        if field == "receiver" and not press then return end
        if field == "tile" and not obj.LootButton:HasUserFocus(pc) then return end
        local current = view
        if get_session(pc) ~= current.session then return end
        local taken, err = current.session.take(current.key, current.id)
        if not taken then
            if err then
                pc:ClientDisplayPlayerMessage(FText("Could not save manual pickup. Take it again to retry."))
                error(err)
            end
            return
        end
        press = nil
        ExecuteInGameThreadWithDelay(16, function() if view == current then hide() end end)
        found(pc, current.id)
    end

    hook(panel .. "PopulateLootItems", function(ctx) present(ctx:get()) end)
    hook(panel .. "CloseLoot", function(ctx) if view and same(ctx:get(), view.panel) then hide() end end)
    hook(button .. "1_OnButtonPressedEvent__DelegateSignature", function(ctx)
        if active(ctx:get(), "tile") then press = {} end
    end)
    hook(button .. "2_OnButtonReleasedEvent__DelegateSignature", function(ctx)
        if press and view and same(ctx:get(), view.tile) then
            local released = press
            ExecuteInGameThreadWithDelay(16, function() if press == released then press = nil end end)
        end
    end)
    hook("/Script/UMG.Widget:RemoveFromParent", function(ctx)
        if press then take(ctx:get(), "receiver") end
    end)
    hook(tile .. "LootSelectedItem", function(ctx) take(ctx:get(), "tile") end)
    hook(tile .. "GetLootToolTipWidget", function(ctx) if active(ctx:get(), "tile") then return view.tooltip end end)
    return function()
        hide()
        crate_keys, last_panel = {}, nil
    end, function(pc)
        if pc and valid(pc.Pawn) then
            local ui = pc.Pawn.LootUI
            if valid(ui) and ui:IsVisible() and valid(ui.LootContainerReference)
                and valid(ui.LootItems) and ui.LootItems:GetChildrenCount() > 0 then present(ui) end
        end
    end
end

return M
