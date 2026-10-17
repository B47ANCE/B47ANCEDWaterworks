local waterWorks=require "waterWorks/API"
local H=require "waterWorks/FirstPartySediment"
local Client=require "waterWorks/CommandClient"
local Registry=require "waterWorks/Registry"
local Action=require "waterWorks/SedimentAction"
local Menu={}
local function call(object,name)
    local ok,value=pcall(function()return object[name](object)end);if ok then return value end;return nil
end
local function label(name,...)return getText("UI_B47ANCEDWaterworks_Sediment"..name,...)end
local function claim(object,index)
    local actor=getSpecificPlayer(index);local owned=call(object,"getItem")
    return actor and Client.requestSediment(actor,"claim",nil,nil,{itemId=tostring(call(owned,"getID")),
        x=call(object,"getX"),y=call(object,"getY"),z=call(object,"getZ")})or false
end
local function replace(object,actor,media)return Action.queue(actor,object,"replace",media)end
local function filter(object,actor,target,targetId)return Action.queue(actor,object,"filter",nil,target,targetId)end
function Menu.fill(index,context,worldObjects,test)
    if not context or type(context.addOption)~="function"or type(getText)~="function"then return end
    local actor=type(getSpecificPlayer)=="function"and getSpecificPlayer(index)or nil;if not actor then return end
    local enabled=H.settings().enabled and waterWorks.isFeatureEnabled("EnableNetworkContextActions")
    local inspect=waterWorks.isFeatureEnabled("EnableNetworkInspection")
    local media=enabled and H.findMedia(actor)or nil
    local selected=waterWorks.NetworkContextMenu and waterWorks.NetworkContextMenu.Selections[index]
    local seen={}
    for _,object in ipairs(type(worldObjects)=="table"and worldObjects or{})do
        if object and not seen[object]then
            seen[object]=true;local owned=call(object,"getItem")
            local housing=owned and call(owned,"getFullType")==H.HOUSING_TYPE
            local current=housing and H.presentation(object)
            if housing and (enabled or inspect)then
                if test then return true end
                if not current then
                    if enabled then context:addOption(label("Register"),object,claim,index)end
                else
                    if inspect then
                        for i=#Client.SedimentResults,1,-1 do
                            local last=Client.SedimentResults[i]
                            if last.nodeId==current.nodeId then
                                if not last.ok then local option=context:addOption(label("LastFailed"),nil,nil);if option then option.notAvailable=true end end
                                break
                            end
                        end
                        local text=current.recovery and label("Recovery")or not current.hasMedia and label("Empty")
                            or label("Capacity",string.format("%.2f",current.remaining),string.format("%.2f",current.capacity))
                        local option=context:addOption(text,nil,nil);if option then option.notAvailable=true end
                        local hazard=context:addOption(label("Hazards"),nil,nil);if hazard then hazard.notAvailable=true end
                    end
                    if enabled and not current.recovery and media and (not current.hasMedia or current.remaining<current.capacity
                        or current.capacity~=H.settings().capacity)then
                        context:addOption(label(current.hasMedia and"Replace"or"Install"),object,replace,actor,media)
                    end
                end
            end
            if enabled and selected and selected.object~=object then
                local source,sourceView,target,targetId
                if selected.kind=="filter"then
                    local descriptor=Registry.describeObject(object)
                    if descriptor and(descriptor.node.kind=="storage"or descriptor.node.kind=="fixture")then
                        source=selected.object;sourceView=H.presentation(source);target=object;targetId=descriptor.node.id
                    end
                elseif housing and(selected.kind=="storage"or selected.kind=="fixture")then
                    source=object;sourceView=current;target=selected.object;targetId=selected.nodeId
                end
                if sourceView and sourceView.hasMedia and sourceView.remaining>0 and not sourceView.recovery then
                    if test then return true end
                    context:addOption(label("Filter"),source,filter,actor,target,targetId)
                end
            end
        end
    end
end
if Events and Events.OnFillWorldObjectContextMenu then Events.OnFillWorldObjectContextMenu.Add(Menu.fill)end
return Menu
