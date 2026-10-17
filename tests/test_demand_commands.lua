next=nil;isClient=function()return false end
local sent={};sendServerCommand=function(...)sent[#sent+1]={...}end
Events={OnClientCommand={Add=function()end},OnTick={Add=function()end}}
getGameTime=function()return{getWorldAgeHours=function()return 100 end}end
local iteration=dofile(arg[1]);package.loaded["waterWorks/Iteration"]=iteration
waterWorks={Flow={preview=function(_,source,target,amount)
    if source~="source"or target~="target"then return nil,"bad route"end
    return{amount=amount,path={source,target}}
end,transfer=function()return true,{amount=1}end}}
local scheduler=dofile(arg[2]);package.loaded["waterWorks/DemandScheduler"]=scheduler
local store={nodeIndex={source={networkId="system"},target={networkId="system"}},networks={system={nodes={
    source={id="source",x=0,y=0,z=0},target={id="target",x=1,y=0,z=0}}}}}
local registry={getStore=function()return store end,getRuntimeObject=function()return{}end}
package.loaded["waterWorks/Registry"]=registry;waterWorks.Registry=registry
package.loaded["waterWorks/Network"]={}
package.loaded["waterWorks/Connections"]={DEFAULT_ACTOR_REACH=3,DEFAULT_NODE_DISTANCE=2}
local commands=dofile(arg[3]);package.loaded["waterWorks/Commands"]=commands
local server=dofile(arg[4]);local player={getX=function()return 0 end,getY=function()return 0 end,getZ=function()return 0 end}
local ok,result=server.handle(commands.MODULE,commands.SCHEDULE_DEMAND,player,
    {requestId="one",sourceId="source",targetId="target",amount=2.5,intervalHours=12})
assert(ok and result.ok and result.proposal.nextRunHour==112 and not result.proposal.updated)
local report=scheduler.inspect(store);assert(report.count==1 and report.entries["demand:one"].amount==2.5)
local revision=report.revision
local replay=server.handle(commands.MODULE,commands.SCHEDULE_DEMAND,player,
    {requestId="one",sourceId="source",targetId="target",amount=99,intervalHours=1})
assert(replay and scheduler.inspect(store).revision==revision,"replay must not update schedule")
local updated,updateResult=server.handle(commands.MODULE,commands.SCHEDULE_DEMAND,player,
    {requestId="two",sourceId="source",targetId="target",amount=4,intervalHours=24})
report=scheduler.inspect(store);assert(updated and updateResult.proposal.updated and report.count==1
    and report.entries["demand:one"].amount==4 and report.entries["demand:one"].nextRunHour==124)
assert(server.handle(commands.MODULE,commands.SCHEDULE_DEMAND,player,
    {requestId="bad",sourceId="source",targetId="target",amount=101,intervalHours=1})==false)
local cancelled,cancelResult=server.handle(commands.MODULE,commands.CANCEL_DEMAND,player,
    {requestId="three",sourceId="source",targetId="target"})
assert(cancelled and cancelResult.proposal.cancelled and scheduler.inspect(store).count==0)
assert(server.handle(commands.MODULE,commands.CANCEL_DEMAND,player,
    {requestId="four",sourceId="source",targetId="target"})==false)
local far={getX=function()return 99 end,getY=function()return 0 end,getZ=function()return 0 end}
assert(server.handle(commands.MODULE,commands.SCHEDULE_DEMAND,far,
    {requestId="far",sourceId="source",targetId="target",amount=1,intervalHours=1})==false)
print("B47ANCEDWaterworks authoritative scheduled-demand command checks passed")
