local M = {}

M.families = {
    { "WORKSHOP_A", "WORKSHOP_B", "WORKSHOP_C", "WORKSHOP_D" },
    { "ELECTRONICS_A", "ELECTRONICS_B", "ELECTRONICS_C", "ELECTRONICS_D" },
    { "MUNITIONS_A", "MUNITIONS_B" },
    { "RIG_A", "RIG_B", "RIG_C" },
    { "IFF", "PROVISIONS" },
}

M.tiers = {
    WORKSHOP_A = { title = "Workshop Manual A", price = 100000,
        description = "Basic tools, sheet metal, ribbed tubes, and trauma kit salvage." },
    WORKSHOP_B = { title = "Workshop Manual B", price = 200000,
        description = "Mid-tier tools, field repairs, and electric motors." },
    WORKSHOP_C = { title = "Workshop Manual C", price = 350000,
        description = "Precision tools, industrial materials, and mechanical fabrication." },
    WORKSHOP_D = { title = "Workshop Manual D", price = 600000,
        description = "Exo repairs, specialty fabrication, and Sentient Drill salvage." },
    ELECTRONICS_A = { title = "Electronics Manual A", price = 100000,
        description = "Basic batteries, charging equipment, and lights." },
    ELECTRONICS_B = { title = "Electronics Manual B", price = 200000,
        description = "Improved lights, circuit boards, drives, radios, and Frequency Tap recovery." },
    ELECTRONICS_C = { title = "Electronics Manual C", price = 350000,
        description = "Military electronics, advanced power, and specialized field equipment." },
    ELECTRONICS_D = { title = "Electronics Manual D", price = 600000,
        description = "Quantum storage, wetware, and encrypted computing." },
    MUNITIONS_A = { title = "Munitions Manual A", price = 100000,
        description = "Salvage components from standard ammunition." },
    MUNITIONS_B = { title = "Munitions Manual B", price = 200000,
        description = "Salvage specialist ammunition and make thermite and explosive charges." },
    RIG_A = { title = "Rig Storage Manual A", price = 100000,
        description = "Make low-quality rig storage boxes in all supported slots and sizes." },
    RIG_B = { title = "Rig Storage Manual B", price = 200000,
        description = "Upgrade matching small and medium rig boxes to high quality." },
    RIG_C = { title = "Rig Storage Manual C", price = 350000,
        description = "Upgrade matching large rig boxes to high quality." },
    IFF = { title = "IFF Manual", price = 100000,
        description = "Craft eligible Level 1 IFF chips and downgrade chips within the same faction." },
    PROVISIONS = { title = "Provisions Manual", price = 100000,
        description = "Blend alcohol and upgrade cigarettes." },
}

local included = {}
for _, family in ipairs(M.families) do
    for _, id in ipairs(family) do
        assert(M.tiers[id] and not included[id], "invalid manual shop entry: " .. id)
        included[id] = true
    end
end
for id in pairs(M.tiers) do
    assert(included[id], "manual missing from shop: " .. id)
end

return M
