local M = {}

function M.export(path)
    local registry = StaticFindObject("/Script/AssetRegistry.Default__AssetRegistryHelpers"):GetAssetRegistry()
    assert(registry:IsValid(), "asset registry unavailable")
    local names = {}
    local assets = {}
    assert(registry:GetAssetsByPath(FName("/Game/FW/LootObjects/Containers"), assets, true, true), "no registered container packages")
    for _, asset in ipairs(assets) do
        local package = asset.PackageName
        local name = type(package) == "string" and package or package:ToString()
        if name:match("/BP_[^/]+$") then names[name] = true end
    end
    local paths = {}
    for name in pairs(names) do paths[#paths + 1] = name end
    assert(#paths > 0, "empty container asset listing")
    table.sort(paths)
    local file = assert(io.open(path, "w"))
    local written, err = file:write(table.concat(paths, "\n"), "\n")
    local closed, close_err = file:close()
    assert(written and closed, err or close_err)
    return #paths
end

return M
