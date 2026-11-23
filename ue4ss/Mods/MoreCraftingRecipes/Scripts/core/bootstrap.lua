local standard_recipes = require("recipes/definitions")
local config = {
    definitions = { table.unpack(standard_recipes) },
    extra_groups = require("recipes/groups"),
}
for _, module in ipairs({ "rig/boxes", "recipes/expansion" }) do
    for _, definition in ipairs(require(module)) do
        config.definitions[#config.definitions + 1] = definition
    end
end

local runtime = require("core/runtime")
local settings_reader = require("core/settings")

local M = {}

local function log(message)
    print("[MoreCraftingRecipes] " .. message .. "\n")
end

function M.start(mod_folder, on_ready)
    local settings = settings_reader.read(mod_folder .. "MoreCraftingRecipes.ini", log)
    local visibility_policy, manual_progress
    local refresh
    if settings.books_enabled then
        local ok, policy = pcall(function()
            local progression = require("books/progression")
            local bunco = require("books/game/bunco")
            local progress = progression.new(mod_folder, config.definitions, settings.book_prices)
            bunco.start(mod_folder, progress, log, function()
                ExecuteInGameThread(function()
                    if refresh then refresh() end
                end)
            end)
            return progress
        end)
        if ok then
            manual_progress = policy
            visibility_policy = policy.visibility
        else
            visibility_policy = function() return {} end
            log("Could not start recipe books. Custom recipes are hidden: " .. tostring(policy))
        end
    end

    local crafting_time = settings.instant and require("recipes/crafting_time")
    local installer = crafting_time and require("core/installer")
    local after_install
    if crafting_time or manual_progress or on_ready then
        after_install = function(definitions, report, eligible)
            if crafting_time then
                local recipes = installer.find_table("recipes")
                if recipes then
                    local ok, count = pcall(crafting_time.apply, recipes)
                    if not ok then
                        report("Instant crafting unavailable: " .. tostring(count))
                    elseif count > 0 then
                        report("Instant crafting applied to " .. count .. " recipe rows")
                    end
                end
            end
            if manual_progress then manual_progress.eligible(eligible) end
            if on_ready then on_ready(definitions, report, eligible) end
        end
    end
    refresh = runtime.start(config, after_install, visibility_policy)
end

return M
