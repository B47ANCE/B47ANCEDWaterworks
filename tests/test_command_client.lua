local tickHandler
Events={OnServerCommand={Add=function()end},OnTick={Add=function(fn)tickHandler=fn end}}
local sent={}; sendClientCommand=function(...) sent[#sent+1]={...} end
local commands=dofile(arg[1]); local client=dofile(arg[2])
local player={}
local requested,requestId=client.request(player,"connect","a","b")
assert(requested and type(requestId)=="string" and #sent==1)
assert(client.subscribe(player,"system","a"))
assert(client.configureDemand(player,"source","target",2.5,12));local demandPayload=sent[#sent][4]
assert(sent[#sent][3]==commands.SCHEDULE_DEMAND and demandPayload.amount==2.5 and demandPayload.intervalHours==12)
assert(client.cancelDemand(player,"source","target")and sent[#sent][3]==commands.CANCEL_DEMAND)
assert(client.requestTreatment(player,"purifier","tank","boiled"))
assert(sent[#sent][3]==commands.TREAT and sent[#sent][4].treatmentId=="boiled")
assert(client.requestHeat(player,"purifier","tank",5))
assert(sent[#sent][3]==commands.HEAT and sent[#sent][4].deltaC==5)
assert(client.setValveOpen(player,"valve",false))
assert(sent[#sent][3]==commands.SET_VALVE and sent[#sent][4].open==false)
assert(client.receive(commands.MODULE,commands.SNAPSHOT,{networkId="system",revision=1,cursor=nil,nextCursor="a",
    complete=false,nodes={{id="a"}},edges={}}))
assert(client.Snapshots.system.nodes.a and not client.Snapshots.system.complete)
assert(client.receive(commands.MODULE,commands.SNAPSHOT,{networkId="system",revision=2,cursor="a",nextCursor=nil,
    complete=true,nodes={{id="b"}},edges={}})==false,"mixed-revision continuation must be discarded")
assert(client.Snapshots.system.revision==1 and client.Snapshots.system.nodes.b==nil)
assert(client.receive(commands.MODULE,commands.SNAPSHOT,{networkId="system",revision=1,cursor="a",nextCursor=nil,
    complete=true,nodes={{id="b"}},edges={{a="a",b="b"}}}))
assert(client.Snapshots.system.complete and client.Snapshots.system.nodes.b)
assert(client.receive(commands.MODULE,commands.DELTA,{networkId="system",revision=2}) and #client.Deltas==1)
local completed,completionError
assert(client.requestSnapshot(player,"paged","anchor",function(snapshot,reason)completed=snapshot;completionError=reason end))
assert(client.receive(commands.MODULE,commands.SNAPSHOT,{networkId="paged",revision=5,cursor=nil,nextCursor="n1",
    complete=false,nodes={{id="n1"}},edges={}}))
local before=#sent;assert(tickHandler and tickHandler()and #sent==before+1,"continuation must be deferred and bounded to a tick")
local payload=sent[#sent][4];assert(payload.cursor=="n1"and payload.revision==5,"continuation must bind cursor and revision")
assert(client.receive(commands.MODULE,commands.SNAPSHOT,{networkId="paged",revision=5,cursor="n1",nextCursor=nil,
    complete=true,nodes={{id="n2"}},edges={{a="n1",b="n2"}}}))
assert(completed and completed.complete and completed.nodes.n2 and completionError==nil,"completed pages must notify the requester")
local rejected
assert(client.requestSnapshot(player,"rejected","anchor",function(_,reason)rejected=reason end))
assert(client.receive(commands.MODULE,commands.SNAPSHOT_ERROR,{networkId="rejected",reason="out of reach"}))
assert(rejected=="out of reach"and client.PendingSnapshots.rejected==nil,"snapshot errors must terminate pending UI work")
print("B47ANCEDWaterworks client snapshot revision/cursor checks passed")
