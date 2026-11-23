local installer = require("core/installer")
local catalog = require("tools/catalog")
local containers = require("tools/containers")
local bootstrap = require("core/bootstrap")

local source = debug.getinfo(1, "S").source:gsub("^@", "")
local mod_directory = assert(source:match("^(.*[\\/])Scripts[\\/][^\\/]+$"), "mod directory unavailable")
local catalog_path = mod_directory .. "crafting-items.tsv"
local complete = false
local containers_exported = false

bootstrap.start(mod_directory, function(definitions, log)
    if not containers_exported then
        local ok, count = pcall(containers.export, mod_directory .. "container-assets.txt")
        containers_exported = ok
        if ok then log("Exported " .. count .. " container blueprints to container-assets.txt")
        else log("Container asset export unavailable: " .. tostring(count)) end
    end
    if complete then return end
    local recipes = installer.find_table("recipes")
    if not recipes then return end

    local ok, count, missing = pcall(catalog.export, recipes, definitions, catalog_path)
    if not ok then
        log("Catalog export failed: " .. tostring(count))
        return
    end

    complete = #missing == 0
    if complete then
        log(string.format("Exported %d item tags to %s", count, catalog_path))
    end
end)
