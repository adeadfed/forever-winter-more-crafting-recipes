local manuals = require("books/manuals")
local store = require("books/store")
local purchase = require("books/purchase")
local objects = require("books/game/objects")
local ui = require("books/game/bunco_cards")
local wallet = require("books/game/bunco_wallet")

local M = {}
local vendor_class = "/Game/Widgets/Vendors/W_Vendor.W_Vendor_C"
local collapsed = 1

local function is_bunco(vendor)
    return objects.valid(vendor) and vendor:IsVisible() and vendor.VendorPanel:IsVisible()
        and vendor.VendorData.RowName:ToString() == "ScavSurplusVendor"
        and objects.same(vendor.CategorySelected, vendor.CategoryConsumables)
end

local function live(class, address)
    for _, object in ipairs(FindAllOf(class) or {}) do
        if object:GetAddress() == address and objects.valid(object) then return object end
    end
end

function M.start(folder, progress, log, refresh)
    local acquire = purchase.new(store, folder, log)
    local pending, last_error

    local function update_cards(vendor)
        if not objects.valid(vendor) or vendor.VendorData.RowName:ToString() ~= "ScavSurplusVendor" then return end
        local scroll = vendor.VendorSB
        if not objects.valid(scroll) then return end
        local shelf = ui.find_shelf(scroll)
        if not is_bunco(vendor) then
            if shelf and shelf:GetVisibility() ~= collapsed then shelf:SetVisibility(collapsed) end
            return
        end
        local prices = progress.prices()
        if not shelf and next(prices) then
            local pc = wallet.controller(vendor)
            if not pc then return end
            shelf = ui.create_shelf(vendor, pc, prices)
            log("Added Dossier manual cards to Bunco's Consumables tab.")
        end
        if shelf then ui.update_shelf(shelf, prices) end
    end

    local function select_card(card)
        local tier, shelf = ui.offer_for(card)
        local price = tier and progress.prices()[tier]
        if not price then return end
        local outer = shelf:GetOuter()
        local vendor = objects.valid(outer) and outer:GetOuter() or nil
        if not is_bunco(vendor) or not objects.same(shelf:GetParent(), vendor.VendorSB) then return end
        local pc = wallet.controller(vendor)
        if not pc then return end

        if pending then
            local old = live("WBP_PopUp_C", pending.popup)
            if objects.valid(old) and old:IsInViewport() then return end
        end
        local popup = ui.popup(pc)
        local manual = manuals.tiers[tier]
        local prompt = {
            popup = popup:GetAddress(),
            vendor = vendor:GetAddress(),
            tier = tier,
            price = price,
            title = manual.title,
            detail = "Buy for " .. ui.format_price(price) .. " CR?",
        }
        pending = prompt
        popup:AddToViewport(201)
        ui.popup_text(popup, prompt)
        for _, delay in ipairs({ 75, 300 }) do
            ExecuteInGameThreadWithDelay(delay, function()
                if pending ~= prompt then return end
                local current = live("WBP_PopUp_C", prompt.popup)
                if objects.valid(current) and current:IsInViewport() then pcall(ui.popup_text, current, prompt) end
            end)
        end
    end

    local function answer(popup, confirmed)
        if not pending or not objects.valid(popup) or popup:GetAddress() ~= pending.popup then return end
        local prompt = pending
        pending = nil
        if not confirmed or not prompt.tier then
            popup:RemoveFromParent()
            return
        end

        local vendor = live("W_Vendor_C", prompt.vendor)
        local pc = is_bunco(vendor) and wallet.controller(vendor) or nil
        local credits = pc and wallet.open(pc)
        local manual = manuals.tiers[prompt.tier]
        local success, reason
        if progress.prices()[prompt.tier] ~= prompt.price then
            reason = "This offer changed. Select the manual again."
        elseif credits then
            local ok, result, err = pcall(acquire, prompt.tier, prompt.price, credits)
            success, reason = ok and result, ok and err or "Purchase unavailable. Check the mod log."
            if not ok then log("Manual purchase failed: " .. tostring(result)) end
        else
            reason = "Bunco's credits wallet is unavailable."
        end

        if not success then
            prompt.detail, prompt.tier = reason, nil
            pending = prompt
            ui.popup_text(popup, prompt)
            return
        end

        progress.learn(prompt.tier)
        popup:RemoveFromParent()
        pcall(function() vendor:InitializePlayerCurrency() end)
        update_cards(vendor)
        refresh()
        log("Learned " .. manual.title .. " at Bunco.")
    end

    local function callback(fn)
        return function(context)
            local ok, err = pcall(fn, context:get())
            if not ok and err ~= last_error then log("Bunco manual shop: " .. tostring(err)) end
            if not ok then last_error = err end
        end
    end

    local hooks = {
        { ui.card_path .. ":BndEvt__W_VendorItem_ItemButton_K2Node_ComponentBoundEvent_0_OnButtonClickedEvent__DelegateSignature", select_card },
        { ui.popup_path .. ":OnConfirm", function(popup) answer(popup, true) end },
        { ui.popup_path .. ":OnCancel", function(popup) answer(popup, false) end },
    }
    for _, name in ipairs({ "ApplyCategory", "RefreshFilter", "ToggleVendorListState", "PassiveRefreshVendorRank" }) do
        hooks[#hooks + 1] = { vendor_class .. ":" .. name, update_cards }
    end
    local function bind()
        for _, hook in ipairs(hooks) do
            if not objects.valid(StaticFindObject(hook[1])) then
                ExecuteInGameThreadWithDelay(1500, bind)
                return
            end
        end
        for _, hook in ipairs(hooks) do RegisterHook(hook[1], callback(hook[2])) end
    end
    ExecuteInGameThread(bind)
end

return M
