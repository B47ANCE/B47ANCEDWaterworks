require "TimedActions/ISBaseTimedAction"
local waterWorks=rawget(_G,"waterWorks")or require "waterWorks/API"
local Sampling=waterWorks.Sampling or require "waterWorks/Sampling"
local Client=waterWorks.SamplingClient or require "waterWorks/SamplingClient"
local Action=ISBaseTimedAction:derive("waterWorks_SamplingAction")
waterWorks_SamplingAction=Action
local function call(object,name,...)
    local ok,fn=pcall(function()return object and object[name]end);if not ok or type(fn)~="function"then return nil end
    local called,value=pcall(fn,object,...);if called then return value end;return nil
end
local function close(character,object)
    local x,y,z=tonumber(call(character,"getX")),tonumber(call(character,"getY")),tonumber(call(character,"getZ"))
    local ox,oy,oz=tonumber(call(object,"getX")),tonumber(call(object,"getY")),tonumber(call(object,"getZ"))
    if not x or not y or not z or not ox or not oy or not oz then return false end
    local dx,dy,dz=x-ox,y-oy,(z-oz)*3;return dx*dx+dy*dy+dz*dz<=9
end
function Action:isValid()
    if not Sampling.isEnabled()or self._sent or not self.character or call(self.character,"isDead")~=false or not close(self.character,self.target)then return false end
    local adapter=waterWorks.getContainer(self.target);if not adapter or tonumber(adapter:getAmount())<=0 then return false end
    if self.mode=="kit"then
        if not self.kit or tostring(call(self.kit,"getID"))~=self.kitId or call(self.kit,"getFullType")~=Sampling.KIT_TYPE
            or call(self.kit,"getContainer")==nil then return false end
        local uses,delta=tonumber(call(self.kit,"getCurrentUsesFloat")),tonumber(call(self.kit,"getUseDelta"))
        if not uses or not delta or uses+0.0001<delta then return false end
    end
    return true
end
function Action:start()end;function Action:update()end
function Action:stop()ISBaseTimedAction.stop(self)end;function Action:perform()ISBaseTimedAction.perform(self)end
function Action:complete()
    if self._sent or not self:isValid()then return false end;self._sent=true
    return Client.request(self.character,self.target,self.mode,self.kit)==true
end
function Action:new(character,target,mode,kit)
    local o=ISBaseTimedAction.new(self,character);o.character=character;o.target=target;o.mode=mode;o.kit=kit
    o.kitId=kit and tostring(call(kit,"getID"))or nil;o.stopOnWalk=true;o.stopOnRun=true
    o.maxTime=(mode=="kit"and 120 or 45)*Sampling.getTimeMultiplier()
    if call(character,"isTimedActionInstant")==true then o.maxTime=1 end;return o
end
function waterWorks.queueSamplingAction(character,target,mode,kit)
    if not character or not target or(mode~="inspect"and mode~="kit")then return false,"sampling inputs required"end
    if mode=="kit"and not kit then return false,"water test kit required"end
    require "TimedActions/ISTimedActionQueue";ISTimedActionQueue.add(Action:new(character,target,mode,kit));return true
end
waterWorks.SamplingAction=Action
return Action
