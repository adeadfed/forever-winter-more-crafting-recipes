local M = {}
local objects = require("books/game/objects")
local cards = require("books/game/bunco_cards")
local tile_path = "/Game/Widgets/Inventory/W_LootItem.W_LootItem_C"
local data_path = "/Game/Blueprints/Data/ItemDetailsData.ItemDetailsData"
local name_prefix = "MCR_RaidManual_"
local serial = 0
local native_click = "BndEvt__W_LootItem_LootButton_K2Node_ComponentBoundEvent_0_OnButtonClickedEvent__DelegateSignature"
local panel_events = { "LootItem", "LootItemPressed", "LootItemRelease", "LootItemDrag", "LootItemHovered", "LootItemUnhovered" }

local valid, same = objects.valid, objects.same

local function class(path)
    local found = StaticFindObject(path)
    assert(valid(found), "unavailable class or asset " .. path)
    return found
end

local function name_of(binding)
    local name = binding.FunctionName
    return type(name) == "string" and name or name:ToString()
end

local function isolate(tile, receiver)
    for _, event in ipairs(panel_events) do
        assert(#(tile[event]:GetBindings() or {}) == 0, "new tile already routes " .. event)
    end
    local click = tile.LootButton.OnClicked
    for _, binding in ipairs(click:GetBindings() or {}) do
        assert(same(binding.Object, tile) and name_of(binding) == native_click, "unexpected native loot button binding")
        click:Remove(tile, FName(native_click))
    end
    assert(#(click:GetBindings() or {}) == 0, "manual button still reaches stock handler")
    -- Removing this private spacer is the Take signal. It has no inventory behavior.
    click:Add(receiver, FName("RemoveFromParent"))
    local bindings = click:GetBindings() or {}
    assert(#bindings == 1 and same(bindings[1].Object, receiver) and name_of(bindings[1]) == "RemoveFromParent",
        "private Take binding unavailable")
end

function M.detach(view)
    if view and valid(view.wrapper) and valid(view.wrapper:GetParent()) then view.wrapper:RemoveFromParent() end
end

function M.clear_stale(grid)
    for i = grid:GetChildrenCount()-1, 0, -1 do
        local child = grid:GetChildAt(i)
        if child:GetFName():ToString():sub(1, #name_prefix) == name_prefix then child:RemoveFromParent() end
    end
end

local function named_child(widget, name)
    if widget:GetFName():ToString() == name then return widget end
    local ok, count = pcall(function() return widget:GetChildrenCount() end)
    if ok then
        for i = 0, count - 1 do
            local child = named_child(widget:GetChildAt(i), name)
            if child then return child end
        end
    end
end

local function native_tooltip(card, manual)
    local tooltip = card:Get_ItemButton_ToolTipWidget()
    assert(valid(tooltip), "native item tooltip unavailable")
    local root = tooltip.WidgetTree.RootWidget
    local title, description = named_child(root, "ItemName"), named_child(root, "ItemDescription")
    assert(valid(title) and valid(description), "unexpected native item tooltip layout")
    title:SetText(FText(manual.title))
    description:SetText(FText(manual.description))
    return tooltip
end

function M.attach(ui, pc, id, manual)
    local grid, tree = ui.LootItems, ui.WidgetTree
    assert(valid(grid) and grid:GetClass():GetFName():ToString() == "WrapBox", "loot grid unavailable")
    local size = ui.LootIconSize
    assert(type(size) == "number" and size > 0, "loot icon size unavailable")
    serial = serial + 1
    local wrapper = StaticConstructObject(class("/Script/UMG.SizeBox"), tree, FName(name_prefix .. os.time() .. "_" .. serial))
    wrapper:SetVisibility(1)
    wrapper:SetWidthOverride(size)
    wrapper:SetHeightOverride(size)
    local view = { wrapper = wrapper }
    local ok, err = pcall(function()
        local data = class(data_path)
        local dossier = assert(data:FindRow("Plans05"), "Dossier unavailable")
        local display_name = cards.display_row(data, dossier, id, manual)
        local library = class("/Script/UMG.Default__WidgetBlueprintLibrary")
        local tile = library:Create(pc, class(tile_path), pc)
        assert(valid(tile), "could not create the stock loot tile")
        local overlay = StaticConstructObject(class("/Script/UMG.Overlay"), tree)
        wrapper:AddChild(overlay)
        overlay:AddChildToOverlay(tile)
        grid:AddChildToWrapBox(wrapper)
        assert(same(wrapper:GetParent(), grid), "could not append manual to the loot grid")
        local item = { ItemRowHandle = { DataTable = data, RowName = FName("Plans05") }, Quantity = 1, IsInUse = true, Hidden = false }
        tile:SetData(-1, true, 0.0, size, item)
        assert(tile.ContainerItem.ItemRowHandle.RowName:ToString() == "Plans05", "Dossier tile data unavailable")
        local card_class = StaticFindObject(cards.card_path)
        if not valid(card_class) then card_class = LoadAsset(cards.card_path) end
        assert(valid(card_class), "manual artwork widget unavailable")
        local card = library:Create(pc, card_class, pc)
        assert(valid(card), "native manual display unavailable")
        local art_slot = overlay:AddChildToOverlay(card)
        art_slot:SetHorizontalAlignment(0)
        art_slot:SetVerticalAlignment(0)
        card:SetVisibility(3) -- HitTestInvisible, including the vendor button.
        local function paint()
            local result = {}
            card:InitialiseItem({ ItemRowHandle = item.ItemRowHandle, Quantity = 1 }, { X=size, Y=size }, false, result)
            assert(result.Initialized ~= false, "Dossier artwork did not initialize")
            card.ItemData.ItemRowHandle.RowName = display_name
            card.ItemName:SetText(FText(manual.title))
            card.Cost:SetVisibility(1)
            card:SetVisibility(3)
        end
        paint()
        local built, tooltip = pcall(native_tooltip, card, manual)
        if not built then
            print("[MoreCraftingRecipes] Native raid tooltip unavailable: " .. tostring(tooltip) .. "\n")
            tooltip = StaticConstructObject(class("/Script/UMG.Border"), tree)
            tooltip:SetBrushColor({ R=0.02, G=0.02, B=0.02, A=0.96 })
            local text = StaticConstructObject(class("/Script/UMG.TextBlock"), tree)
            text:SetFont(card.ItemName.Font)
            text.WrapTextAt = 180
            text:SetText(FText(manual.title .. "\n\n" .. manual.description))
            tooltip:SetContent(text)
        end
        local receiver = StaticConstructObject(class("/Script/UMG.Spacer"), tree)
        receiver:SetVisibility(1)
        overlay:AddChildToOverlay(receiver)
        local button = tile.LootButton
        button:RemoveFromParent()
        local content = button:GetContent()
        if valid(content) then content:SetVisibility(1) end
        local input_slot = overlay:AddChildToOverlay(button)
        input_slot:SetHorizontalAlignment(0)
        input_slot:SetVerticalAlignment(0)
        button:SetBackgroundColor({ R=1, G=1, B=1, A=0 })
        button:SetIsEnabled(true)
        button:SetVisibility(0)
        button:SetToolTip(tooltip)
        tile:SetVisibility(1)
        isolate(tile, receiver)
        view.tile, view.receiver, view.tooltip = tile, receiver, tooltip
        -- Update the native card once after its first layout, when its image has a size.
        ExecuteInGameThreadWithDelay(65, function()
            if valid(wrapper) and same(wrapper:GetParent(), grid) and valid(card) then pcall(paint) end
        end)
        wrapper:SetVisibility(0)
    end)
    if not ok then M.detach(view); error(err, 0) end
    return view
end

return M
