local manuals = require("books/manuals")
local objects = require("books/game/objects")

local M = {}
M.card_path = "/Game/Widgets/Vendors/W_VendorItem.W_VendorItem_C"
M.popup_path = "/Game/FW/UI/MainMenu/UMG/Panels/WBP_PopUp.WBP_PopUp_C"
local shelf_prefix = "MCR_BuncoManualShelf_"
local visible, collapsed = 0, 1
local dossier_table = "/Game/Blueprints/Data/ItemDetailsData.ItemDetailsData"
local widget_library = "/Script/UMG.Default__WidgetBlueprintLibrary"
local serial = 0

local function create_user_widget(path, pc)
    local library = StaticFindObject(widget_library)
    local class = StaticFindObject(path)
    assert(objects.valid(library) and objects.valid(class), "vendor widget class unavailable")
    local widget = library:Create(pc, class, pc)
    assert(objects.valid(widget), "could not create vendor widget")
    return widget
end

local function is_shelf(widget)
    return objects.valid(widget) and widget:GetFName():ToString():sub(1, #shelf_prefix) == shelf_prefix
end

function M.find_shelf(scroll)
    for index = 0, scroll:GetChildrenCount() - 1 do
        local child = scroll:GetChildAt(index)
        if is_shelf(child) then return child end
    end
end

function M.format_price(price)
    return tostring(price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function set_card_price(card, price)
    if card.Value ~= price then card.Value = price end
    local cost = card.Cost
    if not objects.valid(cost) then return end
    local kind = cost:GetClass():GetFName():ToString()
    if kind == "W_VendorCurrency_C" then
        if cost.CurrencyValue ~= price then cost.CurrencyValue = price end
        return
    end
    local ok, current = pcall(function() return cost:GetText():ToString() end)
    if not ok then return end
    local numbers = M.format_price(price)
    local text, replaced = current:gsub("%d[%d,.]*", numbers, 1)
    if replaced == 0 then text = numbers .. " CR" end
    if text ~= current then cost:SetText(FText(text)) end
end

local function display_row(data, dossier, tier, manual)
    local id = "MCR_BuncoManual_" .. tier
    local row = data:FindRow(id)
    if not row then
        data:AddRow(id, dossier)
        row = assert(data:FindRow(id), "could not create manual display data")
        row.ItemName = FText(manual.title)
        row.ItemDescription = FText(manual.description)
    end
    assert(row.ItemName:ToString() == manual.title and row.ItemDescription:ToString() == manual.description,
        "manual display data does not match " .. tier)
    return FName(id)
end

function M.create_shelf(vendor, pc, prices)
    local data = StaticFindObject(dossier_table)
    local vertical = StaticFindObject("/Script/UMG.VerticalBox")
    local horizontal = StaticFindObject("/Script/UMG.HorizontalBox")
    local scroll, tree = vendor.VendorSB, vendor.WidgetTree
    local currency = vendor.W_PlayerCurrency
    assert(objects.valid(data), "item data unavailable")
    local dossier = assert(data:FindRow("Plans05"), "Dossier row unavailable")
    local dossier_name = dossier.ItemName:ToString()
    local dossier_description = dossier.ItemDescription:ToString()
    assert(objects.valid(vertical) and objects.valid(horizontal)
        and objects.valid(tree) and objects.valid(currency), "vendor layout unavailable")
    local saved = { ItemRowHandle = { DataTable = data, RowName = FName("Plans05") }, Quantity = 1 }
    local size = math.floor((vendor.PanelSize - 8) / 4)
    assert(size >= 50, "vendor card size unavailable")

    serial = serial + 1
    local name = shelf_prefix .. os.time() .. "_" .. serial
    local shelf = StaticConstructObject(vertical, tree, FName(name))
    assert(objects.valid(shelf), "could not create manual shelf")
    for index, family in ipairs(manuals.families) do
        local row = StaticConstructObject(horizontal, shelf, FName(name .. "_Row_" .. index))
        assert(objects.valid(row), "could not create manual row")
        for _, id in ipairs(family) do
            local manual = manuals.tiers[id]
            local card = create_user_widget(M.card_path, pc)
            local output = {}
            local tooltip_row = display_row(data, dossier, id, manual)
            card:InitialiseItem(saved, { X = size, Y = size }, false, output)
            assert(output.Initialized ~= false, "Dossier artwork did not initialize")
            -- Use a display-only row for the tooltip.
            card.ItemData.ItemRowHandle.RowName = tooltip_row
            assert(card.ItemData.ItemRowHandle.RowName:ToString() == tooltip_row:ToString(), "manual tooltip row did not apply")
            local price = prices[id] or manual.price
            card:InitialiseCost(price, currency, 1.0)
            set_card_price(card, price)
            card.ItemName:SetText(FText(manual.title))
            local slot = row:AddChildToHorizontalBox(card)
            assert(objects.valid(slot), "could not insert manual card")
            slot:SetPadding({ Left = 1, Top = 1, Right = 1, Bottom = 1 })
        end
        assert(objects.valid(shelf:AddChildToVerticalBox(row)), "could not attach the manual row")
    end
    assert(dossier.ItemName:ToString() == dossier_name and dossier.ItemDescription:ToString() == dossier_description,
        "original Dossier display data changed")
    local slot = scroll:AddChild(shelf)
    assert(objects.valid(slot) and objects.same(shelf:GetParent(), scroll), "could not attach the manual cards")
    return shelf
end

local function set_visibility(widget, show)
    local state = show and visible or collapsed
    if widget:GetVisibility() ~= state then widget:SetVisibility(state) end
end

function M.update_shelf(shelf, prices)
    set_visibility(shelf, next(prices) ~= nil)
    for index, family in ipairs(manuals.families) do
        local row = shelf:GetChildAt(index - 1)
        local any = false
        for column, id in ipairs(family) do
            local card, price = row:GetChildAt(column - 1), prices[id]
            set_visibility(card, price ~= nil)
            if price then
                any = true
                set_card_price(card, price)
            end
        end
        set_visibility(row, any)
    end
end

function M.offer_for(card)
    if not objects.valid(card) then return end
    local row = card:GetParent()
    local shelf = objects.valid(row) and row:GetParent()
    if not is_shelf(shelf) then return end
    for index, family in ipairs(manuals.families) do
        if objects.same(shelf:GetChildAt(index - 1), row) then
            for column, id in ipairs(family) do
                if objects.same(row:GetChildAt(column - 1), card) then return id, shelf end
            end
        end
    end
end

function M.popup(pc)
    return create_user_widget(M.popup_path, pc)
end

local function find(widget, name, depth)
    if not objects.valid(widget) or depth > 8 then return end
    if widget:GetFName():ToString() == name then return widget end
    local panel, count = pcall(function() return widget:GetChildrenCount() end)
    if not panel then return end
    for index = 0, count - 1 do
        local result = find(widget:GetChildAt(index), name, depth + 1)
        if result then return result end
    end
end

function M.popup_text(popup, prompt)
    local root = popup.WidgetTree.RootWidget
    local description = find(root, "TextDescription", 0)
    local panel = find(root, "PanelTemplateWidget", 0)
    local timer = find(root, "TextTimer", 0)
    assert(objects.valid(description), "purchase dialog text unavailable")
    description:SetText(FText(prompt.detail))
    if objects.valid(panel) then
        local label = find(panel.WidgetTree.RootWidget, "TextTitle", 0)
        if objects.valid(label) then label:SetText(FText(prompt.title)) end
    end
    if objects.valid(timer) then timer:SetVisibility(1) end
end

return M
