local waterWorks=rawget(_G,"waterWorks") or {}
local Commands={MODULE="waterWorks",CONNECT="connectNodes",DISCONNECT="disconnectNodes",
    RESULT="connectionResult",DELTA="connectionDelta",SUBSCRIBE="subscribeNetwork",
    SNAPSHOT="networkSnapshot",SNAPSHOT_ERROR="networkSnapshotError",CLAIM_PUMP="claimPlacedPump",
    CLAIM_TREATMENT="claimPlacedTreatment",CLAIM_VALVE="claimPlacedValve",CLAIM_FIXTURE="claimVanillaFixture",
    SET_VALVE="setValveOpen",FLOW="transferFlow",TREAT="treatNetworkContainer",HEAT="heatNetworkContainer",
    REPAIR="repairInfrastructure",SAMPLE="sampleWater",SAMPLE_RESULT="waterSampleResult",
    SCHEDULE_DEMAND="scheduleDemand",CANCEL_DEMAND="cancelDemand",
    MAX_NODE_ID=128,MAX_REQUEST_ID=64,MAX_NETWORK_ID=128,MAX_ITEM_ID=64,MAX_FLOW_AMOUNT=100,
    MIN_DEMAND_INTERVAL=0.01,MAX_DEMAND_INTERVAL=8760}
waterWorks.Commands=Commands
_G.waterWorks=waterWorks
return Commands
