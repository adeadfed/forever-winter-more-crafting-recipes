local installer = require("core/installer")

local list_groups = "/Script/Engine.DataTableFunctionLibrary:GetDataTableRowNames"
local station = "/Game/FW/UI/Manufactoring/UI/WBP_ManufactoringStation.WBP_ManufactoringStation_C"

local M = {}

function M.start(config, on_ready, visibility_policy)
    local reported_group_table
    local pending = false
    local attempts = 0

    local function log(message)
        print("[MoreCraftingRecipes] " .. message .. "\n")
    end

    local function apply()
        local ok, ready, eligible = pcall(installer.install, config, log, visibility_policy)
        if not ok then
            log("Could not restore recipes: " .. tostring(ready))
            return false
        end
        if ready and on_ready then
            on_ready(config.definitions, log, eligible)
        end
        return ready
    end

    -- Install before Manufacturing snapshots the category rows.
    local hooked, hook_error = pcall(RegisterHook, list_groups, function(_, table_param)
        if not table_param then return end
        local data = table_param:get()
        if not installer.is_group_table(data) then return end
        local address = data:GetAddress()
        if apply() and reported_group_table ~= address then
            reported_group_table = address
            log("Prepared recipes before Manufacturing read its categories")
        end
    end)
    if not hooked then log("Could not watch Manufacturing category read: " .. tostring(hook_error)) end

    local run_install
    local function queue_install()
        attempts = 30
        if not pending then
            pending = true
            ExecuteInGameThread(function() run_install(true) end)
        end
    end

    run_install = function(preload)
        attempts = attempts - 1
        if preload == true then
            local ok, err = pcall(installer.preload_tables)
            if not ok then log("Could not preload Manufacturing tables: " .. tostring(err)) end
        end
        if apply() then
            pending = false
        elseif attempts > 0 then
            ExecuteInGameThreadWithDelay(1000, run_install)
        else
            pending = false
            log("Manufacturing tables are still unavailable. The next load event will retry.")
        end
    end

    NotifyOnNewObject("/Script/Engine.DataTable", function(object)
        if installer.is_manufacturing_table(object:GetFName():ToString()) then queue_install() end
    end)
    NotifyOnNewObject(station, queue_install)
    RegisterLoadMapPostHook(function() queue_install() end)
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
        queue_install()
    end)
    queue_install()

    return apply
end

return M
