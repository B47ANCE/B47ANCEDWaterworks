local Client=require "waterWorks/CommandClient"
local Inspector={MAX_ROWS=512}

local function escape(value)
    return tostring(value or""):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")
end
function Inspector.format(snapshot)
    if type(snapshot)~="table"or type(snapshot.nodes)~="table"or type(snapshot.edges)~="table"then return nil,"invalid snapshot"end
    local ids={};for id in pairs(snapshot.nodes)do ids[#ids+1]=id end;table.sort(ids)
    local kinds,components,enabled,shown={},{},0,math.min(#ids,Inspector.MAX_ROWS)
    for _,id in ipairs(ids)do
        local node=snapshot.nodes[id]
        local kind=escape(type(node)=="table"and node.kind or"unknown");kinds[kind]=(kinds[kind]or 0)+1
        local component=type(node)=="table"and node.componentId or nil;if component~=nil then components[tostring(component)]=true end
        if type(node)=="table"and node.enabled~=false then enabled=enabled+1 end
    end
    local componentCount=0;for _ in pairs(components)do componentCount=componentCount+1 end
    local lines={"<H1>Water Network: "..escape(snapshot.networkId).."</H1>",
        "Revision: "..tostring(tonumber(snapshot.revision)or 0),
        "Nodes: "..tostring(#ids).." (enabled "..tostring(enabled)..")",
        "Connections: "..tostring((function()local n=0;for _ in pairs(snapshot.edges)do n=n+1 end;return n end)()),
        "Components: "..tostring(tonumber(snapshot.componentCount)or componentCount),"<LINE>","<H2>Node types</H2>"}
    local kindIds={};for kind in pairs(kinds)do kindIds[#kindIds+1]=kind end;table.sort(kindIds)
    for _,kind in ipairs(kindIds)do lines[#lines+1]=kind..": "..tostring(kinds[kind])end
    lines[#lines+1]="<LINE>";lines[#lines+1]="<H2>Nodes</H2>"
    for index=1,shown do
        local id=ids[index];local node=snapshot.nodes[id]
        lines[#lines+1]=string.format("%s | %s | %s | %.0f, %.0f, %.0f",escape(id),escape(node.kind),
            node.enabled==false and"disabled"or"enabled",tonumber(node.x)or 0,tonumber(node.y)or 0,tonumber(node.z)or 0)
    end
    if shown<#ids then lines[#lines+1]="... "..tostring(#ids-shown).." more nodes omitted"end
    return table.concat(lines,"<BR>")
end
local function show(text,playerIndex)
    local ok=pcall(require,"ISUI/ISCollapsableModalRichText")
    if not ok or not rawget(_G,"ISCollapsableModalRichText")or not rawget(_G,"getCore")then return false,"inspection UI unavailable"end
    local width,height=620,520;local core=getCore();local x=(core:getScreenWidth()-width)/2;local y=(core:getScreenHeight()-height)/2
    local modal=ISCollapsableModalRichText:new(x,y,width,height,text,false,nil,nil,playerIndex or 0)
    modal:initialise();modal:addToUIManager();modal:setTitle(type(getText)=="function" and getText("UI_B47ANCEDWaterworks_NetworkInspector") or "B47ANCE’d Waterworks Network Inspector");return true,modal
end
function Inspector.open(player,descriptor,playerIndex)
    local node=descriptor and descriptor.node
    if not player or type(descriptor)~="table"or type(descriptor.networkId)~="string"or type(node)~="table"or type(node.id)~="string"then
        return false,"network endpoint unavailable"
    end
    return Client.requestSnapshot(player,descriptor.networkId,node.id,function(snapshot,reason)
        local text=snapshot and Inspector.format(snapshot)or("<H1>Water Network</H1><BR>Inspection failed: "..escape(reason))
        show(text,playerIndex)
    end)
end
Inspector.show=show
return Inspector
