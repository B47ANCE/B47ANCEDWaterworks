next=nil -- Build 42 Kahlua release compatibility.
local attachedStore={nodeIndex={known=true}}
local calls={attach=0,detach=0}
local Registry={getStore=function()return attachedStore end,
    reattachObject=function(_,object)if object.known then calls.attach=calls.attach+1;return true end;return false,"unknown"end,
    detachObject=function(_,object)if object.attached then calls.detach=calls.detach+1;object.attached=false;return true end;return false,"not attached"end}
package.loaded["waterWorks/Registry"]=Registry
local handlers={}
local Events={}
for _,name in ipairs({"LoadGridsquare","ReuseGridsquare","OnObjectAdded","OnObjectAboutToBeRemoved"})do
    Events[name]={Add=function(fn)handlers[name]=fn end}
end
local Lifecycle=dofile(arg[1])
assert(Lifecycle.install(Events)and Lifecycle.install(Events),"lifecycle installation must be idempotent")
local known={known=true,attached=true};local unknown={};local values={known,unknown,known}
local list={size=function()return #values end,get=function(_,index)return values[index+1]end}
local square={getObjects=function()return list end,getWorldObjects=function()return list end,getSpecialObjects=function()return nil end}
handlers.LoadGridsquare(square)
assert(calls.attach==1,"square load must reattach each existing persistent object once")
handlers.OnObjectAdded(unknown);assert(calls.attach==1,"object-added must not auto-claim unknown infrastructure")
handlers.OnObjectAdded(known);assert(calls.attach==2,"object-added must restore a known node")
handlers.ReuseGridsquare(square);assert(calls.detach==1,"square reuse must detach each runtime object once")
known.attached=true;handlers.OnObjectAboutToBeRemoved(known);assert(calls.detach==2,"object removal must detach runtime identity")
local before=Lifecycle.inspect();assert(before.squaresLoaded==1 and before.squaresReused==1 and before.errors==0)
Registry.reattachObject=function()error("provider exploded")end
handlers.OnObjectAdded(known)
assert(Lifecycle.inspect().errors==1,"event failures must be contained and counted")
print("B47ANCEDWaterworks bounded authoritative object lifecycle checks passed")
