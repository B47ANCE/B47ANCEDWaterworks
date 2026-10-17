"""Offline Lua 5.1 tests; engine objects are stubs, never PZ runtime proof."""
import argparse,json,os
from pathlib import Path
from lupa.lua51 import LuaRuntime

CASES={
'identity':[],
'api':['API'],
'command_client':['Commands','client/CommandClient'],
'commands':['Network','Registry','Connections','Commands','server/CommandServer'],
'condition':['API','Network','Registry','Condition'],
'connections':['Network','Registry','Connections'],
'demand_commands':['Iteration','DemandScheduler','Commands','server/CommandServer'],
'demand_dialog':['Commands','client/DemandDialog'],
'demand_scheduler':['DemandScheduler'],
'diagnostics':['Network','Registry','Diagnostics'],
'filter_transactions':[],
'filters':['Filters'],
'first_party_pumps':['POWER','Network','Registry','Infrastructure','PumpPower','FirstPartyPumps'],
'first_party_treatment':['POWER','Network','Registry','Infrastructure','PumpPower','FirstPartyTreatment'],
'first_party_valves':['Network','Registry','Infrastructure','FirstPartyValves'],
'fixture_claim_command':['API','Network','Registry','Infrastructure','VanillaProviders','Commands','server/CommandServer'],
'fixture_context_menu':['Commands','client/CommandClient','client/FixtureContextMenu'],
'flow':['API','Network','Registry','Infrastructure','Hydraulics','Flow'],
'flow_command':['API','Network','Registry','Infrastructure','Hydraulics','Flow','PumpPower','Commands','server/CommandServer'],
'hydraulics':['API','Network','Registry','Infrastructure','Hydraulics'],
'infrastructure':['API','Network','Registry','Infrastructure'],
'lifecycle':['server/Lifecycle'],
'load_graph':['client/Load','server/Load'],
'maintenance':['API','Network','Registry','Infrastructure','Condition','Maintenance','Commands','server/CommandServer'],
'maintenance_action':['Commands','client/CommandClient','client/MaintenanceAction'],
'maintenance_context_menu':['client/MaintenanceContextMenu'],
'network':['Network'],
'network_context_menu':['client/NetworkContextMenu'],
'network_inspector':['client/NetworkInspector'],
'network_timed_action':['Commands','client/CommandClient','client/NetworkTimedAction'],
'persistence_contract':['API','Network','Registry','Infrastructure','Condition','Thermal','DemandScheduler','Maintenance'],
'plumbing_conformance':['API','Network','Registry','Infrastructure','PlumbingConformance'],
'powered_flow':['POWER','API','Network','Registry','Infrastructure','Hydraulics','PumpPower','Flow'],
'pump_content':['SCRIPT'],
'pump_context_menu':['Commands','client/CommandClient','client/PumpContextMenu'],
'pump_placement_command':['POWER','Network','Registry','Infrastructure','PumpPower','FirstPartyPumps','Commands','server/CommandServer'],
'pump_power':['API','Network','Registry','Infrastructure','PumpPower'],
'registry':['Network','Registry'],
'sampling':['API','Sampling'],
'sampling_action':['API','Commands','Sampling','client/SamplingClient','client/SamplingAction'],
'sampling_client':['Commands','client/SamplingClient'],
'sampling_context_menu':['client/SamplingContextMenu'],
'sampling_distribution':['server/SamplingDistribution'],
'sampling_server':['API','Commands','Sampling','server/SamplingServer'],
'thermal':['API','Network','Registry','Infrastructure','Thermal','Flow'],
 'treatment_context_menu':['Commands','client/CommandClient','client/TreatmentContextMenu'],
 'treatment_devices':['POWER','API','Network','Registry','Infrastructure','PumpPower','TreatmentDevices','Thermal','Commands','server/CommandServer'],
 'treatment_placement_command':['POWER','API','Network','Registry','Infrastructure','PumpPower','FirstPartyTreatment','Commands','server/CommandServer'],
 'valve_context_menu':['Commands','client/CommandClient','client/ValveContextMenu'],
 'valve_placement_command':['Network','Registry','Infrastructure','FirstPartyValves','Commands','server/CommandServer'],
 'vanilla_providers':['API','Network','Registry','Infrastructure','VanillaProviders'],
}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--power-root',type=Path)
    p.add_argument('--report',type=Path);args=p.parse_args();root=args.root.resolve();os.chdir(root)
    inv=json.loads((root/'version-inventory.json').read_text(encoding='utf-8'));media=root/inv['source_root']/'42/media';lua=media/'lua'
    power=args.power_root.resolve() if args.power_root else None
    power_api=power/'src/B47ANCEDPower/42/media/lua/shared/B47ANCEDPower/API.lua' if power else None
    def resolve(name):
        if name=='POWER':return power_api
        if name=='SCRIPT':return media/'scripts/B47ANCEDWaterworks_Items.txt'
        if '/' in name:side,stem=name.split('/',1)
        else:side,stem='shared',name
        return lua/side/'waterWorks'/(stem+'.lua')
    expected={'test_'+key+'.lua'for key in CASES}
    actual={f.name for f in (root/'tests').glob('test_*.lua')}
    assert expected==actual,'unmapped test files: '+str(expected^actual)
    paths=[(lua/side/'?.lua').as_posix()for side in ['shared','client','server']]
    if power:paths.append((power/'src/B47ANCEDPower/42/media/lua/shared/?.lua').as_posix())
    passed=[];failed={};skipped=[];syntax=[]
    for file in sorted(lua.rglob('*.lua')):
        vm=LuaRuntime(unpack_returned_tuples=True)
        try:vm.execute('assert(loadfile(...))',file.as_posix());syntax.append(file.relative_to(root).as_posix())
        except Exception as exc:failed['syntax:'+file.name]=str(exc)
    for name,entries in CASES.items():
        if 'POWER'in entries and not power_api:skipped.append(name);continue
        vm=LuaRuntime(unpack_returned_tuples=True);vm.execute('print=function()end; table.unpack=table.unpack or unpack')
        vm.globals().package.path=';'.join(paths)+';'+vm.globals().package.path
        vm.globals().arg=vm.table_from({i+1:resolve(n).as_posix()for i,n in enumerate(entries)})
        try:vm.execute('dofile(...)',(root/'tests'/('test_'+name+'.lua')).as_posix());passed.append(name)
        except Exception as exc:failed[name]=str(exc)
    report={'environment':'offline Windows; Lua 5.1 via lupa; native objects stubbed','version':(root/'VERSION').read_text(encoding='utf-8').strip(),'passed':passed,'failed':failed,'skipped':skipped,'syntax_files':len(syntax)}
    if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(f'Lua 5.1: {len(passed)} PASS, {len(failed)} FAIL, {len(skipped)} optional Power tests SKIPPED; {len(syntax)} syntax files')
    for name,error in failed.items():print(name+': '+error)
    return bool(failed)
if __name__=='__main__':raise SystemExit(main())
