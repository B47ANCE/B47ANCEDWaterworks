local waterWorks=rawget(_G,"waterWorks")or require "waterWorks/API"
local Commands=require "waterWorks/Commands"
local Client={Results={},MAX_HISTORY=32};local counter=0
local function call(object,name)
    local ok,value=pcall(function()return object and object[name](object)end);if ok then return value end;return nil
end
local function escape(value)return tostring(value or""):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")end
local function label(value)return tostring(value or"unknown"):gsub("_"," "):lower():gsub("^%l",string.upper)end
function Client.identity(object)
    local x,y,z=call(object,"getX"),call(object,"getY"),call(object,"getZ")
    if x==nil or y==nil or z==nil then return nil,"water-source coordinates unavailable"end
    local item=call(object,"getItem")
    if item then
        local id,kind=call(item,"getID"),call(item,"getFullType")
        if id==nil or type(kind)~="string"or kind==""then return nil,"world-item identity unavailable"end
        return{targetKind="worldItem",x=x,y=y,z=z,itemId=tostring(id),itemType=kind}
    end
    local index,sprite=call(object,"getObjectIndex"),call(object,"getSpriteName")
    if index==nil or type(sprite)~="string"or sprite==""then return nil,"water-object identity unavailable"end
    return{targetKind="object",x=x,y=y,z=z,objectIndex=index,spriteName=sprite}
end
function Client.request(player,object,mode,kit)
    if type(sendClientCommand)~="function"then return false,"sendClientCommand unavailable"end
    if mode~="inspect"and mode~="kit"then return false,"unsupported sampling mode"end
    local payload,err=Client.identity(object);if not payload then return false,err end
    counter=counter+1;payload.requestId="waterWorks.sample:"..tostring(counter);payload.mode=mode
    if mode=="kit"then
        local id=call(kit,"getID");if id==nil then return false,"water test kit required"end;payload.kitId=tostring(id)
    end
    local ok,value=pcall(sendClientCommand,player,Commands.MODULE,Commands.SAMPLE,payload)
    if not ok then return false,value end;return true,payload.requestId
end
function Client.format(report)
    if type(report)~="table"then return nil,"invalid water sample"end
    local lines={"<H1>Water Sample</H1>","Amount: "..string.format("%.2f / %.2f",tonumber(report.amount)or 0,tonumber(report.capacity)or 0),
        "Appearance: "..escape(label(report.appearance)),"Odor: "..escape(label(report.odor)),
        "Vanilla taint warning: "..(report.vanillaTainted and"Yes"or"No")}
    if report.mode=="kit"then
        lines[#lines+1]="<LINE>";lines[#lines+1]="<H2>Test Kit Results</H2>"
        lines[#lines+1]="Overall: "..escape(label(report.qualityState));lines[#lines+1]="Treatment: "..escape(label(report.treatment))
        for _,key in ipairs({"biological","particulate","chemical","salinity","turbidity"})do
            lines[#lines+1]=label(key)..": "..escape(label(type(report.axes)=="table"and report.axes[key]or nil))
        end
    else lines[#lines+1]="<LINE>Visual inspection cannot rule out invisible contamination."end
    return table.concat(lines,"<BR>")
end
local function show(report,reason)
    local text=report and Client.format(report)or("<H1>Water Sample</H1><BR>Sampling failed: "..escape(reason))
    local loaded=pcall(require,"ISUI/ISCollapsableModalRichText")
    if loaded and rawget(_G,"ISCollapsableModalRichText")and rawget(_G,"getCore")then
        local width,height=520,430;local core=getCore();local modal=ISCollapsableModalRichText:new(
            (core:getScreenWidth()-width)/2,(core:getScreenHeight()-height)/2,width,height,text,false,nil,nil,0)
        modal:initialise();modal:addToUIManager();modal:setTitle(type(getText)=="function" and getText("UI_B47ANCEDWaterworks_WaterSample") or "B47ANCE’d Waterworks Water Sample");return true
    end
    if print then print("[B47ANCEDWaterworks][Sample] "..tostring(reason or(report and report.qualityState)or"result"))end;return false
end
function Client.receive(module,command,args)
    if module~=Commands.MODULE or command~=Commands.SAMPLE_RESULT or type(args)~="table"then return false end
    Client.Results[#Client.Results+1]=args;while#Client.Results>Client.MAX_HISTORY do table.remove(Client.Results,1)end
    show(args.ok and args.report or nil,args.reason);return true
end
if Events and Events.OnServerCommand then Events.OnServerCommand.Add(Client.receive)end
waterWorks.SamplingClient=Client
return Client
