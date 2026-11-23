local M = {}

function M.new(store, folder, log)
    local function finish(tier)
        local committed, err = store.commit_purchase(folder, tier)
        if not committed then
            log("Could not save manual " .. tier .. ": " .. tostring(err))
            return nil, "Select this manual again to finish the purchase. There is no second charge."
        end
        return true
    end

    return function(tier, price, wallet, confirm_recovery)
        local learned, _, receipts = store.learned(folder)
        if learned[tier] then return true end
        local before = wallet.balance()
        local receipt = receipts[tier]
        if receipt then
            if type(receipt) == "table" then
                if not before then return nil, "Credits unavailable." end
                if before == receipt.before - receipt.price then return finish(tier) end
                if before == receipt.before then
                    local cleared, why = store.cancel_purchase(folder, tier)
                    if not cleared then log("Could not cancel interrupted purchase: " .. tostring(why)) end
                    return nil, "Your balance is unchanged. Select the manual again to buy it."
                end
            end
            -- Other trades or an older receipt can make the debit impossible to reconstruct.
            if confirm_recovery then return finish(tier) end
            return nil, "Select this manual again to review the interrupted purchase."
        end
        if confirm_recovery then return nil, "This purchase was already resolved." end
        if not before then return nil, "Credits unavailable." end
        if before < price then return nil, "Insufficient credits." end

        local staged, err = store.stage_purchase(folder, tier, before, price)
        if not staged then
            log("Could not stage manual " .. tier .. ": " .. tostring(err))
            return nil, "Purchase unavailable. Check the mod log."
        end

        local called, debit_error = pcall(wallet.debit, price)
        local read, after = pcall(wallet.balance)
        if not called then log("Native debit raised an error: " .. tostring(debit_error)) end
        if read and after == before then
            local cancelled, why = store.cancel_purchase(folder, tier)
            if not cancelled then log("Could not clear declined purchase: " .. tostring(why)) end
            return nil, "Bunco did not take payment. Try again."
        end
        if not read or after ~= before - price then
            log("Uncertain wallet result for " .. tier .. ". Kept the purchase receipt.")
            return nil, "Payment status unclear. Select this manual again. There is no second charge."
        end

        local recorded, why = store.record_outcome(folder, "paid", { [tier] = true })
        if not recorded then log("Could not record verified payment: " .. tostring(why)) end
        log("Verified payment of " .. price .. " credits for manual " .. tier)
        return finish(tier)
    end
end

return M
