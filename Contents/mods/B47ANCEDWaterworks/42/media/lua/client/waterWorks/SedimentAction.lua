require "TimedActions/ISBaseTimedAction"
local H=require "waterWorks/FirstPartySediment"
local Client=require "waterWorks/CommandClient"
local Action=ISBaseTimedAction:derive("waterWorks_SedimentAction")
waterWorks_SedimentAction=Action
local function call(object,name)
    local ok,value=pcall(function()return object[name](object)end);if ok then return value end;return nil
end
local function near(actor,object)
    local x,y,z=call(actor,"getX"),call(actor,"getY"),call(actor,"getZ")
    local ox,oy,oz=call(object,"getX"),call(object,"getY"),call(object,"getZ")
    return x and y and z and ox and oy and oz and math.floor(z)==math.floor(oz)and (x-ox)^2+(y-oy)^2<=9
end
function Action:isValid()
    local current=H.presentation(self.housing)
    return not self._sent and not self._stopped and H.settings().enabled and self.character
        and call(self.character,"isDead")==false and near(self.character,self.housing)
        and current and current.nodeId==self.nodeId and current.generation==self.generation and not current.recovery
        and(self.mode~="filter"or self.target and near(self.character,self.target))
        and(self.mode~="replace"or self.media and tostring(call(self.media,"getID"))==self.mediaId
            and call(self.media,"getContainer")==self.mediaContainer)
end
function Action:start()end
function Action:update()end
function Action:stop()self._stopped=true;ISBaseTimedAction.stop(self)end
-- Only submit intent from local completion. All resource/state mutation is in the server handler.
function Action:perform()
    if self:isValid()then
        self._sent=true
        Client.requestSediment(self.character,self.mode,self.nodeId,self.generation,
            {mediaId=self.mediaId,targetId=self.targetId})
    end
    ISBaseTimedAction.perform(self)
end
function Action:new(actor,housing,mode,media,target,targetId)
    local o=ISBaseTimedAction.new(self,actor);local current=H.presentation(housing)
    o.character=actor;o.housing=housing;o.mode=mode;o.media=media;o.target=target;o.targetId=targetId
    o.nodeId=current and current.nodeId;o.generation=current and current.generation
    o.mediaId=media and tostring(call(media,"getID"))or nil;o.mediaContainer=media and call(media,"getContainer")
    o.stopOnWalk=true;o.stopOnRun=true;o.maxTime=120*H.settings().time
    if call(actor,"isTimedActionInstant")==true then o.maxTime=1 end
    return o
end
function Action.queue(actor,housing,mode,media,target,targetId)
    if mode~="replace"and mode~="filter"then return false end
    local action=Action:new(actor,housing,mode,media,target,targetId)
    if not action:isValid()then return false end
    require "TimedActions/ISTimedActionQueue";ISTimedActionQueue.add(action);return true
end
return Action
