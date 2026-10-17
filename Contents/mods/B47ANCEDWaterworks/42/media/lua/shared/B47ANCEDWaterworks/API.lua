-- Reuse an API already executed by the engine/legacy loader; avoid re-registering treatments.
local api=rawget(_G,"waterWorks")
if type(api)=="table" and type(api.getQuality)=="function" then return api end
return require "waterWorks/API"
