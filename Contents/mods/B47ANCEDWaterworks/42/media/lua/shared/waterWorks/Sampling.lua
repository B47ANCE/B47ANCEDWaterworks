local waterWorks=rawget(_G,"waterWorks")or require "waterWorks/API"
local Sampling={SCHEMA_VERSION=1,KIT_TYPE="waterWorks.WaterTestKit",MAX_ITEMS=512}

function Sampling.isEnabled()
    local root=rawget(_G,"SandboxVars");local values=type(root)=="table"and root.waterWorks or nil
    return not(type(values)=="table"and values.EnableWaterSampling==false)
end
function Sampling.getTimeMultiplier()
    local root=rawget(_G,"SandboxVars");local values=type(root)=="table"and root.waterWorks or nil
    local value=type(values)=="table"and tonumber(values.SamplingTimeMultiplier)or 1
    return math.max(.1,math.min(10,value or 1))
end
function Sampling.getLootChance()
    local root=rawget(_G,"SandboxVars");local values=type(root)=="table"and root.waterWorks or nil
    local value=type(values)=="table"and tonumber(values.WaterTestKitLootChance)or .02
    return math.max(0,math.min(1,value or .02))
end

local function copy(value)
    if type(value)~="table"then return value end
    local result={};for key,entry in pairs(value)do
        if type(entry)=="table"then result[key]=copy(entry)
        elseif type(entry)=="string"or type(entry)=="number"or type(entry)=="boolean"then result[key]=entry end
    end
    return result
end
local function band(value)
    value=math.max(0,math.min(1,tonumber(value)or 0))
    if value<.02 then return"NONE"end
    if value<.20 then return"LOW"end
    if value<.45 then return"MODERATE"end
    if value<.80 then return"HIGH"end
    return"SEVERE"
end
local function appearance(quality)
    local value=math.max(quality.particulate,quality.turbidity)
    if value<.10 then return"CLEAR"end
    if value<.25 then return"SLIGHTLY_CLOUDY"end
    if value<.50 then return"CLOUDY"end
    return"HEAVILY_CLOUDED"
end
local function odor(quality)
    local value=math.max(quality.biological,quality.chemical)
    if value<.20 then return"NO_OBVIOUS_ODOR"end
    if value<.45 then return"UNUSUAL_ODOR"end
    return"STRONG_OR_FOUL_ODOR"
end

function Sampling.describe(owner,mode)
    if not Sampling.isEnabled()then return nil,"water sampling disabled"end
    mode=mode=="kit"and"kit"or mode=="inspect"and"inspect"or nil
    if not mode then return nil,"unsupported sampling mode"end
    local inspected,err=waterWorks.inspectContainer(owner);if not inspected then return nil,err end
    if not tonumber(inspected.amount)or inspected.amount<=0 then return nil,"water source is empty"end
    local quality=waterWorks.normalizeQuality(inspected.quality)
    local result={schemaVersion=Sampling.SCHEMA_VERSION,mode=mode,kind=tostring(inspected.kind or"unknown"),
        amount=math.max(0,tonumber(inspected.amount)or 0),capacity=math.max(0,tonumber(inspected.capacity)or 0),
        appearance=appearance(quality),odor=odor(quality),vanillaTainted=inspected.tainted==true}
    if mode=="kit"then
        result.qualityState=waterWorks.deriveQualityState(quality)
        result.treatment=tostring(quality.treatment or"untreated"):sub(1,64)
        result.axes={biological=band(quality.biological),particulate=band(quality.particulate),
            chemical=band(quality.chemical),salinity=band(quality.salinity),turbidity=band(quality.turbidity)}
    end
    return result
end

function Sampling.sanitize(report)
    if type(report)~="table"or report.schemaVersion~=Sampling.SCHEMA_VERSION then return nil end
    local result={schemaVersion=1,mode=report.mode,kind=report.kind,amount=report.amount,capacity=report.capacity,
        appearance=report.appearance,odor=report.odor,vanillaTainted=report.vanillaTainted==true}
    if report.mode=="kit"then
        result.qualityState=report.qualityState;result.treatment=report.treatment;result.axes={}
        for _,key in ipairs({"biological","particulate","chemical","salinity","turbidity"})do
            result.axes[key]=type(report.axes)=="table"and report.axes[key]or nil
        end
    end
    return result
end

Sampling.band=band
waterWorks.Sampling=Sampling
waterWorks.describeWaterSample=Sampling.describe
return Sampling
