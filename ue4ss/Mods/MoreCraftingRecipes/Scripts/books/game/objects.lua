local M = {}

function M.valid(object)
    return object and object:IsValid()
end

function M.same(left, right)
    return M.valid(left) and M.valid(right) and left:GetAddress() == right:GetAddress()
end

return M
