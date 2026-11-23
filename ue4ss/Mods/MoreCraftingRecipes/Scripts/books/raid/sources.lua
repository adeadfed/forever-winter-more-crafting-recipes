local manuals = require("books/manuals")
local M = {}

-- The stock EconV2 crate blueprints use the same six families at T1 through T4.
local families = {
    Civilian = { "WORKSHOP_A", "ELECTRONICS_A", "RIG_A", "PROVISIONS" },
    Material = { "WORKSHOP_A", "WORKSHOP_B", "WORKSHOP_C", "WORKSHOP_D", "RIG_A", "RIG_B", "RIG_C" },
    Medical = { "WORKSHOP_A", "PROVISIONS" },
    Provision = { "PROVISIONS" },
    Armament = { "MUNITIONS_A", "MUNITIONS_B", "IFF" },
    Army = { "ELECTRONICS_A", "ELECTRONICS_B", "ELECTRONICS_C", "ELECTRONICS_D", "RIG_B", "RIG_C", "IFF" },
}
local sectors = { "A", "B", "C", "D" }
local covered = {}
for _, ids in pairs(families) do
    for _, id in ipairs(ids) do
        assert(manuals.tiers[id], "unknown raid manual: " .. id)
        covered[id] = true
    end
end
for id in pairs(manuals.tiers) do assert(covered[id], "missing raid source for " .. id) end

local classes = {}
for tier, sector in ipairs(sectors) do
    for family in pairs(families) do
        local name = ("BP_LootContainer_%s_T%d"):format(family, tier)
        local path = ("/Game/FW/LootObjects/Containers/EconV2/Parity/T%d/%s.%s_C"):format(tier, name, name)
        classes[path] = { family = family, sector = sector }
    end
end

function M.container(class_name, world_name)
    local source = classes[class_name:match("(/Game/.*)$")]
    if not source or not world_name:match("^World /Game/") or world_name:find("/HUB_World/", 1, true)
        or world_name:find("/UI/", 1, true) then return end
    local tunnel = world_name:match("/ProceduralTunnels/Dungeons/Tunnel([1-4])/L_Dungeon_Tunnel%1_%d+%.")
    local sector = sectors[tonumber(tunnel)] or source.sector
    if sector then return sector, families[source.family] end
end

function M.matches(id, sector)
    local tier = id:match("_([A-D])$")
    return tier == nil or tier == sector
end

return M
