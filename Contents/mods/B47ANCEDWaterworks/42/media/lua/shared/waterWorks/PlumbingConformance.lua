local waterWorks=rawget(_G,"waterWorks")or{}
local Infrastructure=waterWorks.Infrastructure or require "waterWorks/Infrastructure"
local Conformance={SCHEMA_VERSION=1,MAX_FIXTURES=32,MAX_ISSUES=64}
local roles={source="source",sink="fixture",storage="storage",fixture="fixture",valve="valve",pump="pump",
    collector="source",treatment="treatment",filter="filter",meter="meter",junction="junction"}
local required={source={"supply","quality"},sink={"demand"},storage={"amount","capacity","quality"},fixture={"demand"},
    valve={"open","flowLimit"},pump={"pressure","flowLimit","powered"},collector={"supply","capacity","quality"},
    treatment={"treatmentId","flowLimit"},filter={"filterId","remainingCapacity","flowLimit"},meter={},junction={}}
local registered={}

local function validId(value,maximum)return type(value)=="string"and value~=""and#value<=maximum and not value:find("[%c]")end
local function scalar(value)return type(value)=="string"or type(value)=="number"or type(value)=="boolean"end
local function add(report,code,message,index)
    if #report.issues<Conformance.MAX_ISSUES then report.issues[#report.issues+1]={code=code,message=message,fixture=index}end
end
local function descriptorValid(value)
    return type(value)=="table"and validId(value.networkId or value.channel,128)and validId(value.channel,64)
        and validId(value.stableKey,192)
end

function Conformance.evaluate(definition,fixtures)
    local report={schemaVersion=1,status="failed",adapterId=type(definition)=="table"and definition.id or nil,
        checked=0,matched=0,rejected=0,issues={}}
    if type(definition)~="table"then add(report,"definition","adapter definition required");return report end
    if not validId(definition.id,64)then add(report,"id","bounded adapter id required")end
    if not roles[definition.role]then add(report,"role","supported plumbing role required")end
    if definition.authority~="server"then add(report,"authority","server authority declaration required")end
    local lifecycle=definition.lifecycle
    if type(lifecycle)~="table"or lifecycle.claim~="explicit"or lifecycle.unload~="detach"or lifecycle.removal~="decommission"then
        add(report,"lifecycle","explicit claim/detach/decommission lifecycle required")
    end
    local provider=definition.provider
    if type(provider)~="table"or type(provider.matches)~="function"or type(provider.describe)~="function"then
        add(report,"provider","matches and describe callbacks required");return report
    end
    if roles[definition.role]and provider.kind~=roles[definition.role]then add(report,"kind","provider kind does not match declared role")end
    if type(provider.getState)~="function"then add(report,"state","getState callback required")end
    if type(fixtures)~="table"or#fixtures<1 or#fixtures>Conformance.MAX_FIXTURES then
        add(report,"fixtures","one to 32 explicit fixtures required");return report
    end
    for index,fixture in ipairs(fixtures)do
        report.checked=report.checked+1
        if type(fixture)~="table"or fixture.object==nil or type(fixture.matches)~="boolean"then add(report,"fixture","object and expected match required",index)
        else
            local ok,matched=pcall(provider.matches,fixture.object)
            if not ok or matched~=fixture.matches then add(report,"match","classifier mismatch or failure",index)
            elseif matched then
                report.matched=report.matched+1
                local firstOk,first=pcall(provider.describe,fixture.object);local secondOk,second=pcall(provider.describe,fixture.object)
                if not firstOk or not secondOk or not descriptorValid(first)or not descriptorValid(second)then add(report,"identity","valid explicit descriptor required",index)
                elseif first.stableKey~=second.stableKey or first.networkId~=second.networkId or first.channel~=second.channel then add(report,"identity","descriptor identity is not stable",index)
                elseif fixture.stableKey and first.stableKey~=fixture.stableKey then add(report,"identity","descriptor stable key differs from fixture",index)end
                if type(provider.getState)=="function"then
                    local stateOk,state=pcall(provider.getState,fixture.object,{},{});if not stateOk or type(state)~="table"then add(report,"state","state callback failed",index)
                    else for _,key in ipairs(required[definition.role]or{})do if state[key]==nil or not scalar(state[key])and key~="quality"then add(report,"capability","missing declared "..key,index)end end end
                end
            else
                report.rejected=report.rejected+1
            end
        end
    end
    if report.matched<1 then add(report,"coverage","at least one positive fixture required")end
    if report.rejected<1 then add(report,"coverage","at least one negative fixture required")end
    report.status=#report.issues==0 and"passed"or"failed"
    return report
end
function Conformance.register(definition,fixtures)
    local report=Conformance.evaluate(definition,fixtures);if report.status~="passed"then return false,report end
    if registered[definition.id]then return true,{duplicate=true,report=report,contract=registered[definition.id]}end
    local contract=Infrastructure.registerProvider(definition.provider);registered[definition.id]=contract
    return true,{duplicate=false,report=report,contract=contract}
end

waterWorks.PlumbingConformance=Conformance
_G.waterWorks=waterWorks
return Conformance
