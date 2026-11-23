local M = {}

function M.new(store, folder, log)
    local paid = {}

    local function finish(tier)
        local committed, err = store.commit_purchase(folder, tier)
        if not committed then
            log("Could not save manual " .. tier .. ": " .. tostring(err))
            return nil, "Payment received. Select the manual again to retry saving."
        end
        paid[tier] = nil
        return true
    end

    return function(tier, price, wallet)
        if store.learned(folder)[tier] then return true end
        if paid[tier] then return finish(tier) end

        local before = wallet.balance()
        if not before then return nil, "Credits unavailable." end
        if before < price then return nil, "Insufficient credits." end

        local staged, err = store.stage_purchase(folder, tier)
        if not staged then
            log("Could not stage manual " .. tier .. ": " .. tostring(err))
            return nil, "Purchase unavailable. Check the mod log."
        end

        local called, debit_error = pcall(wallet.debit, price)
        local read, after = pcall(wallet.balance)
        if not called then log("Native debit raised an error: " .. tostring(debit_error)) end
        if not read or after ~= before - price then
            log("Manual " .. tier .. " payment could not be verified. Kept the purchase receipt.")
            return nil, "Payment could not be verified. Check the mod log."
        end

        paid[tier] = true
        log("Verified payment of " .. price .. " credits for manual " .. tier)
        return finish(tier)
    end
end

return M
