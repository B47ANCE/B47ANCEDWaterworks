local Iteration={}

-- Build 42's release Kahlua environment does not expose Lua's global next().
-- Preserve cursor traversal through pairs(), including a safe restart when a
-- runtime cursor was removed between bounded steps.
function Iteration.nextEntry(values,cursor)
    if type(values)~="table"then return nil end
    local firstKey,firstValue=nil,nil
    local sawCursor=cursor==nil
    for key,value in pairs(values)do
        if firstKey==nil then firstKey,firstValue=key,value end
        if sawCursor then return key,value end
        if key==cursor then sawCursor=true end
    end
    if cursor~=nil and not sawCursor then return firstKey,firstValue end
    return nil
end

function Iteration.hasEntries(values)
    if type(values)~="table"then return false end
    for _ in pairs(values)do return true end
    return false
end

return Iteration
