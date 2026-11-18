local config = require("recipes")
local installer = require("mcr_installer")
local catalog = require("mcr_catalog")
local runtime = require("mcr_runtime")

local source = debug.getinfo(1, "S").source:gsub("^@", "")
local mod_directory = assert(source:match("^(.*[\\/])Scripts[\\/][^\\/]+$"), "mod directory unavailable")
local catalog_path = mod_directory .. "crafting-items.tsv"
local complete = false

runtime.start(config, function(definitions, log)
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
