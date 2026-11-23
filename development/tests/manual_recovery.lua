-- Run from the repository root with an empty temporary directory.
package.path = "ue4ss/Mods/MoreCraftingRecipes/Scripts/?.lua;" .. package.path
local dir = assert(arg and arg[1], "expected a fresh test directory")
local open = io.open
for _, name in ipairs({"manuals.ini", "manuals.recovery"}) do
    for _, suffix in ipairs({"", ".bak", ".tmp"}) do
        assert(not open(dir .. "/" .. name .. suffix, "rb"), "use a fresh test directory")
    end
end
local store, purchase = require("books/store"), require("books/purchase")
local fail_save, fail_after_debit, decline = false, false, false
io.open = function(path, mode)
    if fail_save and mode == "wb" and path:match("manuals%.ini%.tmp$") then
        return nil, "simulated INI write failure"
    end
    return open(path, mode)
end
local credits, debits = 1000000, 0
local wallet = {
    balance = function() return credits end,
    debit = function(price)
        if not decline then credits, debits = credits - price, debits + 1 end
        fail_save = fail_after_debit
    end,
}
local function buyer() return purchase.new(store, dir, function() end) end
local function restart()
    package.loaded["books/store"], package.loaded["books/purchase"] = nil, nil
    store, purchase = require("books/store"), require("books/purchase")
end

-- Verified payment survives an unavailable INI, a reload and unrelated spending.
fail_after_debit = true
assert(not buyer()("WORKSHOP_A", 100000, wallet))
assert(credits == 900000 and debits == 1)
restart()
credits = credits + 12000
assert(store.learned(dir).WORKSHOP_A)
fail_save, fail_after_debit = false, false
assert(buyer()("WORKSHOP_A", 100000, wallet) and debits == 1)
assert(not open(dir .. "/manuals.recovery", "rb"))

-- A definite decline remains unpaid through the same failure.
decline, fail_after_debit = true, true
assert(not buyer()("ELECTRONICS_A", 100000, wallet))
restart()
local learned, _, receipts = store.learned(dir)
assert(not learned.ELECTRONICS_A and not receipts.ELECTRONICS_A and debits == 1)
fail_save, fail_after_debit, decline = false, false, false
assert(buyer()("ELECTRONICS_A", 100000, wallet) and debits == 2)

-- An interruption on either side of the native debit has different evidence.
assert(store.stage_purchase(dir, "RIG_A", credits, 100000))
assert(not buyer()("RIG_A", 100000, wallet, true))
assert(not store.learned(dir).RIG_A and debits == 2)
assert(buyer()("RIG_A", 100000, wallet) and debits == 3)
assert(store.stage_purchase(dir, "RIG_B", credits, 200000))
credits = credits - 200000
restart()
assert(buyer()("RIG_B", 250000, wallet) and debits == 3)

assert(store.stage_purchase(dir, "IFF", credits, 100000))
credits = credits - 17000
assert(not buyer()("IFF", 100000, wallet) and not store.learned(dir).IFF)
assert(buyer()("IFF", 100000, wallet, true) and debits == 3)
assert(not buyer()("MUNITIONS_B", credits + 1, wallet))

-- A death decision covers only that batch, even while the main INI is read-only.
local lost = { PROVISIONS = true, MUNITIONS_A = true }
for id in pairs(lost) do assert(store.stage_raid(dir, id)) end
assert(store.stage_raid(dir, "RIG_C"))
fail_save = true
assert(store.record_outcome(dir, "lost", lost))
assert(not store.finish_raid(dir, lost, false))
local journal = dir .. "/manuals.recovery"
assert(os.rename(journal, journal .. ".bak"))
local incomplete = assert(open(journal .. ".tmp", "wb"))
assert(incomplete:write("lost PROV"))
assert(incomplete:close())
restart()
local pending
learned, pending = store.learned(dir)
assert(pending.RIG_C and learned.WORKSHOP_A)
for id in pairs(lost) do assert(not pending[id] and not learned[id]) end
fail_save = false
assert(not store.finish_raid(dir, lost, true))
assert(store.finish_raid(dir, { RIG_C = true }, true))
assert(store.stage_raid(dir, "PROVISIONS"))
assert(store.finish_raid(dir, { PROVISIONS = true }, true))
assert(not open(dir .. "/manuals.recovery", "rb"))

-- Old releases recorded only the manual ID, without either wallet balance.
local file = assert(open(dir .. "/manuals.ini", "ab"))
assert(file:write("\n[PendingPurchases]\nWORKSHOP_C = true\n"))
assert(file:close())
assert(not buyer()("WORKSHOP_C", 350000, wallet))
assert(buyer()("WORKSHOP_C", 350000, wallet, true) and debits == 3)
io.open = open
print("Passed paid, declined and interrupted purchases, repeat confirmations, and death recovery after failed INI writes.")
