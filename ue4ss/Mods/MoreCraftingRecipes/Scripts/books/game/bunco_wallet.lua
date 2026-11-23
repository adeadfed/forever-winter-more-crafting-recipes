local UEHelpers = require("UEHelpers")
local objects = require("books/game/objects")

local M = {}
local save_class = "/Game/FW/Components/BPC_PlayerSaveGames.BPC_PlayerSaveGames_C"
local currency_table = "/Game/Blueprints/Data/CurrencyData.CurrencyData"
local credit_row = "TestCurrency"

function M.controller(vendor)
    local pc = UEHelpers.GetPlayerController()
    if not objects.valid(pc) or not pc:IsLocalController() then return end
    local world = pc:GetWorld()
    if not objects.valid(world) or not world:GetFullName():match("^World /Game/LevelDesign/HUB_World/")
        or not objects.same(world, vendor:GetWorld()) then return end
    local owner = vendor:GetOwningPlayer()
    if not objects.valid(owner) or objects.same(owner, pc) then return pc end
end

function M.open(pc)
    local class = StaticFindObject(save_class)
    local state = pc.PlayerState
    if not (objects.valid(class) and objects.valid(state)) then return end
    local save = state:GetComponentByClass(class)
    local data = StaticFindObject(currency_table)
    if not (objects.valid(save) and objects.valid(data) and data:FindRow(credit_row)) then return end

    local row = FName(credit_row)
    return {
        balance = function()
            local output = {}
            save:GetStashCurrencyCount(row, output)
            local value = output["Currency Amount"]
            if math.type(value) == "integer" and value >= 0 then return value end
        end,
        debit = function(price)
            save:RemoveStashCurrency({
                { CurrencyRow = { DataTable = data, RowName = row }, CurrencyAmount = price },
            })
        end,
    }
end

return M
