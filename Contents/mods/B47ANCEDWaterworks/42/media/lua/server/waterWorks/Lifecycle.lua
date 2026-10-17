local Registry=require "waterWorks/Registry"

local Lifecycle={MAX_OBJECTS_PER_SQUARE=384,installed=false,
    stats={loaded=0,detached=0,ignored=0,errors=0,squaresLoaded=0,squaresReused=0}}

local function call(object,method,...)
    if not object then return false,nil end
    local ok,fn=pcall(function()return object[method]end)
    if not ok or type(fn)~="function"then return false,nil end
    return pcall(fn,object,...)
end
local function store()return Registry.getStore()end
local function attach(object)
    local current=store();if not current or not object then Lifecycle.stats.ignored=Lifecycle.stats.ignored+1;return false end
    local ok,result=Registry.reattachObject(current,object)
    if ok then Lifecycle.stats.loaded=Lifecycle.stats.loaded+1
    else Lifecycle.stats.ignored=Lifecycle.stats.ignored+1 end
    return ok,result
end
local function detach(object)
    local current=store();if not current or not object then Lifecycle.stats.ignored=Lifecycle.stats.ignored+1;return false end
    local ok,result=Registry.detachObject(current,object)
    if ok then Lifecycle.stats.detached=Lifecycle.stats.detached+1
    else Lifecycle.stats.ignored=Lifecycle.stats.ignored+1 end
    return ok,result
end
local function visit(list,seen,remaining,callback)
    if remaining<=0 or not list then return remaining end
    local sizeOk,size=call(list,"size");size=sizeOk and math.min(remaining,math.max(0,math.floor(tonumber(size)or 0)))or 0
    for index=0,size-1 do
        local got,object=call(list,"get",index)
        if got and object and not seen[object]then seen[object]=true;callback(object);remaining=remaining-1;if remaining<=0 then break end end
    end
    return remaining
end
local function scanSquare(square,callback)
    if not square then return 0 end
    local seen,remaining={},Lifecycle.MAX_OBJECTS_PER_SQUARE
    for _,method in ipairs({"getObjects","getWorldObjects","getSpecialObjects"})do
        local ok,list=call(square,method);if ok then remaining=visit(list,seen,remaining,callback)end
        if remaining<=0 then break end
    end
    return Lifecycle.MAX_OBJECTS_PER_SQUARE-remaining
end

function Lifecycle.onLoadGridSquare(square)
    Lifecycle.stats.squaresLoaded=Lifecycle.stats.squaresLoaded+1
    return scanSquare(square,attach)
end
function Lifecycle.onReuseGridSquare(square)
    Lifecycle.stats.squaresReused=Lifecycle.stats.squaresReused+1
    return scanSquare(square,detach)
end
function Lifecycle.onObjectAdded(object)return attach(object)end
function Lifecycle.onObjectAboutToBeRemoved(object)return detach(object)end

local function protected(callback)
    return function(...)
        local ok,result=pcall(callback,...)
        if not ok then
            Lifecycle.stats.errors=Lifecycle.stats.errors+1
            if type(print)=="function"then print("[B47ANCEDWaterworks] Lifecycle callback failed safely: "..tostring(result))end
        end
        return ok and result or nil
    end
end
function Lifecycle.install(events)
    if Lifecycle.installed then return true end
    events=events or rawget(_G,"Events");if type(events)~="table"then return false,"Events unavailable"end
    local bindings={{"LoadGridsquare",Lifecycle.onLoadGridSquare},{"ReuseGridsquare",Lifecycle.onReuseGridSquare},
        {"OnObjectAdded",Lifecycle.onObjectAdded},{"OnObjectAboutToBeRemoved",Lifecycle.onObjectAboutToBeRemoved}}
    for _,binding in ipairs(bindings)do
        local event=events[binding[1]]
        if type(event)~="table"or type(event.Add)~="function"then return false,"event unavailable: "..binding[1]end
    end
    for _,binding in ipairs(bindings)do events[binding[1]].Add(protected(binding[2]))end
    Lifecycle.installed=true;return true
end
function Lifecycle.inspect()
    local result={};for key,value in pairs(Lifecycle.stats)do result[key]=value end;return result
end

return Lifecycle
