require "TimedActions/ISBaseTimedAction"
local waterWorks=rawget(_G,"waterWorks")or require "waterWorks/API"
local Client=waterWorks.CommandClient or require "waterWorks/CommandClient"
local Action=ISBaseTimedAction:derive("waterWorks_MaintenanceAction")
waterWorks_MaintenanceAction=Action
local function call(object,name,...)
    local ok,fn=pcall(function()return object and object[name]end);if not ok or type(fn)~="function"then return nil end
    local called,value=pcall(fn,object,...);if called then return value end;return nil
end
local function close(character,object,radius)
    local x,y,z=call(character,"getX"),call(character,"getY"),call(character,"getZ")
    local ox,oy,oz=call(object,"getX"),call(object,"getY"),call(object,"getZ")
    if not x or not y or not z or not ox or not oy or not oz then return false end
    local dx,dy,dz=x-ox,y-oy,(z-oz)*3;return dx*dx+dy*dy+dz*dz<=radius*radius
end
function Action:isValid()
    if self._sent or not self.character or call(self.character,"isDead")~=false or not close(self.character,self.worldObject,3)then return false end
    return call(self.kit,"getID")==self.kitId and call(self.kit,"getFullType")=="waterWorks.InfrastructurePatchKit"
        and call(self.kit,"getContainer")~=nil
end
function Action:start()end;function Action:update()end
function Action:stop()ISBaseTimedAction.stop(self)end;function Action:perform()ISBaseTimedAction.perform(self)end
function Action:complete()
    if self._sent or not self:isValid()then return false end;self._sent=true
    return Client.requestRepair(self.character,self.nodeId,self.kitId)==true
end
function Action:new(character,nodeId,worldObject,kit)
    local o=ISBaseTimedAction.new(self,character);o.character=character;o.nodeId=nodeId;o.worldObject=worldObject;o.kit=kit
    o.kitId=call(kit,"getID");o.stopOnWalk=true;o.stopOnRun=true;o.maxTime=120
    if call(character,"isTimedActionInstant")==true then o.maxTime=1 end;return o
end
function waterWorks.queueMaintenanceAction(character,nodeId,worldObject,kit)
    if not character or type(nodeId)~="string"or not worldObject or not kit then return false,"maintenance inputs required"end
    require "TimedActions/ISTimedActionQueue";ISTimedActionQueue.add(Action:new(character,nodeId,worldObject,kit));return true
end
waterWorks.MaintenanceAction=Action
return Action
