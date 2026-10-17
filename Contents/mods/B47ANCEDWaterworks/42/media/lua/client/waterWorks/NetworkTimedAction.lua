require "TimedActions/ISBaseTimedAction"
local waterWorks=rawget(_G,"waterWorks") or require "waterWorks/API"
local Client=waterWorks.CommandClient or require "waterWorks/CommandClient"
local Action=ISBaseTimedAction:derive("waterWorks_NetworkTimedAction")
waterWorks_NetworkTimedAction=Action

local function call(object,name,...)
    local ok,fn=pcall(function() return object and object[name] end)
    if not ok or type(fn)~="function" then return nil end
    local called,value=pcall(fn,object,...)
    if called then return value end
    return nil
end
local function close(character,object,radius)
    local x,y,z=call(character,"getX"),call(character,"getY"),call(character,"getZ")
    local ox,oy,oz=call(object,"getX"),call(object,"getY"),call(object,"getZ")
    if not x or not y or not z or not ox or not oy or not oz then return false end
    local dx,dy,dz=x-ox,y-oy,(z-oz)*3; return dx*dx+dy*dy+dz*dz<=radius*radius
end
function Action:isValid()
    if not self.character or call(self.character,"isDead")~=false or self._sent then return false end
    if type(self.sourceId)~="string" or type(self.targetId)~="string" or self.sourceId==self.targetId then return false end
    return self.sourceObject and self.targetObject and close(self.character,self.sourceObject,3)
        and close(self.character,self.targetObject,3)
end
function Action:start() end
function Action:update() end
function Action:stop() ISBaseTimedAction.stop(self) end
function Action:perform() ISBaseTimedAction.perform(self) end
function Action:complete()
    if self._sent or not self:isValid() then return false end
    self._sent=true
    local ok
    if self.mode=="flow" then ok=Client.requestFlow(self.character,self.sourceId,self.targetId,self.amount,self.minimumPressure)
    else ok=Client.request(self.character,self.mode,self.sourceId,self.targetId) end
    return ok==true
end
function Action:new(character,mode,sourceId,targetId,sourceObject,targetObject,amount,minimumPressure)
    local o=ISBaseTimedAction.new(self,character)
    o.character=character; o.mode=mode; o.sourceId=sourceId; o.targetId=targetId
    o.sourceObject=sourceObject; o.targetObject=targetObject
    o.amount=math.max(0.01,tonumber(amount) or 1); o.minimumPressure=math.max(0,tonumber(minimumPressure) or 0)
    o.stopOnWalk=true; o.stopOnRun=true
    o.maxTime=mode=="flow" and math.min(600,40+o.amount*10) or 80
    if call(character,"isTimedActionInstant")==true then o.maxTime=1 end
    return o
end
function waterWorks.queueNetworkAction(character,mode,sourceId,targetId,sourceObject,targetObject,amount,minimumPressure)
    if mode~="connect" and mode~="disconnect" and mode~="flow" then return false,"unsupported network action" end
    require "TimedActions/ISTimedActionQueue"
    ISTimedActionQueue.add(Action:new(character,mode,sourceId,targetId,sourceObject,targetObject,amount,minimumPressure))
    return true
end
waterWorks.NetworkTimedAction=Action
return Action
