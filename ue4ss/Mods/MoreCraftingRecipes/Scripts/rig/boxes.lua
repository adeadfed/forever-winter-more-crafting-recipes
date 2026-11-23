local catalog = require("rig/catalog")

local sizes = {
    { name = "Small", metal = 1, fasteners = 1 },
    { name = "Medium", metal = 2, fasteners = 1 },
    { name = "Large", metal = 3, fasteners = 2 },
}

local function recipe(action, label, output, manual, ingredients)
    local id = action .. "RigBox_" .. output
    return {
        row = "MCR_" .. id,
        tag = "Recipe.MCR." .. id,
        template = "Refinery_Gunpowder",
        group = "MCR_RigBoxes",
        manual = manual,
        name = action .. " " .. label .. " Box",
        ingredients = ingredients,
        outputs = { { tag = "Inventory.Container." .. output, quantity = 1 } },
    }
end

local definitions = {}
for _, slot in ipairs(catalog) do
    for _, size in ipairs(sizes) do
        local pair = slot[size.name]
        local label = size.name .. " " .. slot.position
        definitions[#definitions + 1] = recipe("Craft", label, pair.low, "RIG_A", {
            { tag = "Inventory.Item.RareLoot_129_slats", quantity = size.metal },
            { tag = "Inventory.Item.RareLoot_32_Screws", quantity = size.fasteners },
        })
        local upgrade = {
            { tag = "Inventory.Container." .. pair.low, quantity = 1 },
            { tag = "Inventory.Item.RareLoot_128_sheetmetal", quantity = size.metal },
            { tag = "Inventory.Item.RareLoot_4_DuctTape", quantity = size.fasteners },
        }
        if size.name == "Large" then
            upgrade[2].quantity = 2
            upgrade[3] = { tag = "Inventory.Item.RareLoot_54_SewingKit", quantity = 1 }
            upgrade[4] = { tag = "Inventory.Item.RareLoot_57_CarbonFiberTube", quantity = 1 }
        end
        local manual = size.name == "Large" and "RIG_C" or "RIG_B"
        definitions[#definitions + 1] = recipe("Upgrade", label, pair.high, manual, upgrade)
    end
end

return definitions
