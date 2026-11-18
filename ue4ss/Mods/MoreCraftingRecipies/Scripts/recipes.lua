local function is_munitions_salvage(recipe)
    return recipe.row:match("^MCR_StripAmmo_")
end

local M = {
    extra_groups = {
        {
            row = "MCR_MunitionsDisassembly",
            template = "CryoAmmo",
            name = "Disassembly",
            description = "Recover materials from ammunition.",
            includes = is_munitions_salvage,
        },
        {
            row = "MCR_Disassembly",
            template = "Drone_Components",
            name = "Disassembly",
            description = "Recover materials from equipment.",
            includes = function(recipe)
                return not is_munitions_salvage(recipe)
                    and not recipe.row:match("^MCR_StripIFF")
                    and (recipe.row:match("^MCR_Strip") or recipe.row:match("^MCR_Salvage"))
            end,
        },
    },
}

local function item(row, quantity)
    return { tag = "Inventory.Item." .. row, quantity = quantity }
end

local function has_item(items, tag)
    for _, entry in ipairs(items) do
        if entry.tag == tag then return true end
    end
    return false
end

local function stock_anchor(stock, selector)
    for _, recipe in ipairs(stock) do
        if #recipe.groups > 0 and (recipe.tag == selector or has_item(recipe.outputs, selector)) then
            return recipe
        end
    end
end

local function add(definitions, anchor, id, name, ingredients, outputs, preferred_group)
    local group = anchor.groups[1]
    for _, candidate in ipairs(anchor.groups) do
        if candidate == preferred_group then group = candidate end
    end
    definitions[#definitions + 1] = {
        row = "MCR_" .. id,
        tag = "Recipe.MCR." .. id,
        template = anchor.row,
        group = group,
        name = name,
        ingredients = ingredients,
        outputs = outputs,
    }
end

local function ammo_batch(outputs)
    local batch = {}
    for _, output in ipairs(outputs) do
        local tag = output.tag:lower()
        if not tag:match("^inventory%.item%.item%.ammo%.") or tag:find("grenade", 1, true)
            or tag:find("40mm", 1, true) then
            return nil
        end
        batch[#batch + 1] = { tag = output.tag, quantity = 2 * output.quantity }
    end
    return #batch > 0 and batch or nil
end

function M.build(stock, log)
    local definitions = {}
    for _, recipe in ipairs(stock) do
        if recipe.group_tag == "Recipe.Ammo" and #recipe.groups > 0 and #recipe.ingredients > 0 then
            local batch = ammo_batch(recipe.outputs)
            if batch then
                add(definitions, recipe, "StripAmmo_" .. recipe.row:gsub("[^%w_]", "_"),
                    "Disassemble " .. recipe.name, batch, recipe.ingredients, "CryoAmmo")
            end
        end
    end

    local function recipe(anchor_selector, id, name, ingredients, outputs, fallback_selector)
        local anchor = stock_anchor(stock, anchor_selector)
            or (fallback_selector and stock_anchor(stock, fallback_selector))
        if anchor then
            add(definitions, anchor, id, name, ingredients, outputs)
        else
            log("Skipped " .. id .. ": no linked stock recipe for " .. anchor_selector)
        end
    end

    local scrambler = item("Item.Ammo.FactionGrenade", 3)
    recipe(scrambler.tag, "StripSignalScramblers", "Recover a Frequency Tap",
        { scrambler }, { item("TransTower_Quest_Marker", 1) })

    for _, faction in ipairs({ "Eurasia", "Europa", "Euruskan" }) do
        local prefix = "IFF_" .. faction .. "_"
        local top_level = item(prefix .. "03", 1)
        local mid_level = item(prefix .. "02", 1)
        recipe(mid_level.tag, "StripIFF_" .. faction, "Salvage " .. faction .. " Level 3 IFF",
            { top_level }, { item(prefix .. "02", 2) }, top_level.tag)
        recipe(mid_level.tag, "StripIFF2_" .. faction, "Salvage " .. faction .. " Level 2 IFF",
            { mid_level }, { item(prefix .. "01", 2) }, top_level.tag)
    end

    local trauma_kit = item("RareLoot_85_AdvancedMedicalTools", 1)
    recipe("Recipe.Meds.SmallMeds", "StripTraumaKit", "Salvage a Heavy-Duty Trauma Kit",
        { trauma_kit }, { item("RareLoot_89_Bandages", 2), item("RareLoot_80_MedicalAlchohol", 1),
            item("RareLoot_90_Tourniquets", 1), item("RareLoot_88_MiscMedication", 1) })

    -- Costs below are game inventory units.
    recipe("Recipe.Refinery.Gunpowder", "CraftThermite", "Craft Thermite",
        { item("RareLoot_102_Matches", 3), item("RareLoot_105_ThermalMatches", 2), item("GunPoweder", 2) },
        { item("RareLoot_101_Thermite", 1) })

    local drill = item("RareLoot_47_SentientDrill", 1)
    recipe(drill.tag, "FormCarbonFiberTube", "Form a Carbon Fiber Tube",
        { item("RareLoot_116_CarbonFiber", 3), item("RareLoot_130_3DPrintingmaterial", 1) },
        { item("RareLoot_57_CarbonFiberTube", 1) })

    recipe(drill.tag, "StripSentientDrill", "Disassemble a Sentient Drill",
        { drill, item("RareLoot_55_Multitool", 1) },
        { item("RareLoot_26_AdvancedProcessor", 1), item("RareLoot_74_MachineParts", 1) })

    recipe("Recipe.Food.MRE", "BlendWhiskey", "Blend Whiskey",
        { item("Alcohol04", 2), item("Bar_Vodka", 2) }, { item("Alcohol01", 1) })
    recipe("Recipe.Food.MRE", "MakeBrandy", "Make Brandy from Wine",
        { item("Alcohol05", 3) }, { item("Alcohol02", 1) })
    recipe("Recipe.Food.MRE", "BlendScotch", "Bottle a Scotch-Style Blend",
        { item("Alcohol01", 2) }, { item("Alcohol03", 1) })
    recipe("Recipe.Food.MRE", "BottlePrizedAlcohol", "Bottle a Prized House Blend",
        { item("Alcohol02", 1), item("Alcohol01", 1), item("Alcohol05", 2) },
        { item("Alcohol06_HighValue", 1) })

    recipe("Recipe.Food.MRE", "BlendHinokoCigarettes", "Blend Hinoko Cigarettes",
        { item("Tobacco01", 2), item("RareLoot_118_Coffee", 1) }, { item("Tobacco03", 1) })
    recipe("Recipe.Food.MRE", "BlendNuckyGoldCigarettes", "Blend Nucky Gold Cigarettes",
        { item("Tobacco03", 1), item("Tobacco01", 3) }, { item("Tobacco02", 1) })

    local codebreaker = item("RareLoot_98_Militarycodebreaker", 1).tag
    recipe(codebreaker, "AssembleMilitaryHardDrive", "Assemble a Military Hard Drive",
        { item("RareLoot_14_HDD", 2), item("RareComputerBits", 1) },
        { item("Plans03", 1) }, drill.tag)

    recipe(codebreaker, "RefurbishHardShellLaptop", "Refurbish a Hard Shell Laptop",
        { item("RareLoot_14_HDD", 1), item("RareLoot_11_GPUCaps", 2),
            item("RareLoot_135_RechargeableBattery", 1), item("RareLoot_2_SealantBuildingGlue", 1) },
        { item("Plans09", 1) }, drill.tag)

    recipe(item("RareLoot_31_ElectricMotor", 1).tag, "AssemblePortableGenerator", "Assemble a Portable Generator",
        { item("RareLoot_31_ElectricMotor", 1), item("RareLoot_74_MachineParts", 2),
            item("RareLoot_100_SparkPlug", 2), item("RareLoot_23_PSU", 1) },
        { item("Tools05", 1) }, drill.tag)

    local function workshop_supply(id, name, ingredients, output)
        recipe("Recipe.Refinery.Gunpowder", id, name, ingredients, { item(output, 1) }, drill.tag)
    end

    workshop_supply("AssembleScavengerToolKit", "Assemble a Scavenger's Tool Kit",
        { item("RareLoot_41_Hammer", 1), item("RareLoot_36_ScrewDriver", 1),
            item("RareLoot_44_BasicPliers", 1) }, "Tools06")
    workshop_supply("UpgradeOldToolSet", "Upgrade to an Old Tool Set",
        { item("Tools06", 1), item("RareLoot_40_HandDrill", 1),
            item("RareLoot_43_Wrench", 1) }, "RareLoot_49_NormalToolset")
    workshop_supply("UpgradeIntermediateToolSet", "Upgrade to an Intermediate Tool Set",
        { item("RareLoot_49_NormalToolset", 1), item("RareLoot_45_AdvancedPliers", 1),
            item("RareLoot_50_Ratchet", 1) }, "RareLoot_48_MastertoldSet")
    workshop_supply("UpgradePrecisionToolSet", "Upgrade to a Precision Tool Set",
        { item("RareLoot_48_MastertoldSet", 1), item("RareLoot_55_Multitool", 1),
            item("RareLoot_3_MeasuringTape", 1) }, "Tools10")

    workshop_supply("AssembleEDCMultitool", "Assemble an EDC Multi-tool",
        { item("RareLoot_51_Multitool", 1), item("RareLoot_134_Battery", 1),
            item("RareLoot_11_GPUCaps", 1) }, "RareLoot_55_Multitool")
    workshop_supply("AssembleRechargeableBattery", "Assemble a Rechargeable Battery",
        { item("RareLoot_134_Battery", 2), item("RareLoot_27_Wires", 1) },
        "RareLoot_135_RechargeableBattery")
    workshop_supply("ReinforceRibbedTube", "Reinforce a Ribbed Tube",
        { item("RareLoot_56_Hose", 1), item("RareLoot_4_DuctTape", 1),
            item("RareLoot_2_SealantBuildingGlue", 1) }, "RareLoot_58_RibbedTube")
    workshop_supply("JoinMetalSlats", "Join Metal Slats",
        { item("RareLoot_129_slats", 2), item("RareLoot_35_Nails", 1) }, "RareLoot_128_sheetmetal")
    workshop_supply("SalvagePowerDrillMotor", "Salvage a Power Drill Motor",
        { item("RareLoot_42_Drill", 1), item("RareLoot_36_ScrewDriver", 1) }, "RareLoot_31_ElectricMotor")

    workshop_supply("AssembleAdvancedJoint", "Assemble an Advanced Joint",
        { item("BallBearings", 2), item("RareLoot_31_ElectricMotor", 1),
            item("RareLoot_74_MachineParts", 1) }, "Quest_AdvancedJoint")
    workshop_supply("AssembleTurretComponent", "Assemble a Turret Component",
        { item("RareLoot_128_sheetmetal", 2), item("RareLoot_31_ElectricMotor", 1),
            item("RareLoot_30_Relay", 1), item("RareLoot_27_Wires", 1) }, "Turret_Debris_Loot")

    workshop_supply("AssembleLightBulb", "Assemble a Light Bulb",
        { item("RareLoot_59_ClearTube", 1), item("RareLoot_27_Wires", 1) }, "RareLoot_64_LightBulb")
    workshop_supply("PackLightBulbs", "Pack Light Bulbs",
        { item("RareLoot_64_LightBulb", 2) }, "RareLoot_61_LightBulbs")
    workshop_supply("AssembleESLamp", "Assemble an ES Lamp",
        { item("RareLoot_64_LightBulb", 1), item("RareLoot_11_GPUCaps", 1) }, "RareLoot_65_ESLamp")
    workshop_supply("AssembleUVLightBulb", "Assemble a UV Light Bulb",
        { item("RareLoot_65_ESLamp", 1), item("RareLoot_99_CameraLens", 1) }, "RareLoot_63_UVLightBulb")
    workshop_supply("AssembleBulkheadLights", "Assemble Bulkhead Lights",
        { item("RareLoot_65_ESLamp", 2), item("RareLoot_128_sheetmetal", 2),
            item("RareLoot_30_Relay", 1) }, "RareLoot_62_AdvancedLightBulbs")
    recipe("Recipe.Refinery.Gunpowder", "SalvageIndustrialBlackLight", "Salvage an Industrial Black Light",
        { item("RareLoot_66_Blacklight", 1) },
        { item("RareLoot_63_UVLightBulb", 2), item("RareLoot_27_Wires", 2), item("RareLoot_30_Relay", 1) },
        drill.tag)

    return definitions
end

return M
