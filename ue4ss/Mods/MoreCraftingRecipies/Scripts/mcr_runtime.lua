local installer = require("mcr_installer")

local M = {}

function M.start(config, on_ready)
    local station_path = "/Game/FW/UI/Manufactoring/UI/WBP_ManufactoringStation.WBP_ManufactoringStation_C"
    local station_hooks = {}
    local pending = false
    local attempts = 0

    local function log(message)
        print("[MoreCraftingRecipies] " .. message .. "\n")
    end

    local function apply()
        local ok, ready, definitions = pcall(installer.install, config, log)
        if not ok then
            log("Could not restore recipes: " .. tostring(ready))
            return false
        end
        if ready and on_ready then
            on_ready(definitions, log)
        end
        return ready
    end

    local function hook_station()
        for _, event in ipairs({ "PreConstruct", "Construct" }) do
            if not station_hooks[event] then
                local path = station_path .. ":" .. event
                local fn = StaticFindObject(path)
                if fn and fn:IsValid() then
                    local ok, result = pcall(RegisterHook, path, function()
                        apply()
                    end)
                    if ok then
                        station_hooks[event] = result
                        log("Watching Manufacturing " .. event)
                    else
                        log("Could not hook Manufacturing " .. event .. ": " .. tostring(result))
                    end
                end
            end
        end
    end

    local run_install
    local function queue_install()
        attempts = 30
        if not pending then
            pending = true
            ExecuteInGameThread(function() run_install() end)
        end
    end

    run_install = function()
        attempts = attempts - 1
        hook_station()
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
    NotifyOnNewObject(station_path, queue_install)
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
        queue_install()
    end)
    queue_install()

    return apply
end

return M
