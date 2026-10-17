"""Validate active identity, compatibility surfaces and protected historical bytes offline."""
from pathlib import Path
import hashlib,json,re,subprocess,sys
from check_versions import check

root=Path(__file__).resolve().parents[1]
check(root)
inv=json.loads((root/'version-inventory.json').read_text(encoding='utf-8'))
mod=root/inv['source_root'];lua=mod/'42/media/lua'
seen={}
for path in sorted(mod.rglob('*')):
    if not path.is_file():continue
    relative=path.relative_to(mod).as_posix()
    assert relative.lower() not in seen, 'path case collision: '+relative
    seen[relative.lower()]=relative
    assert path.suffix.lower() not in {'.java','.jar','.class','.dll','.so'}, 'non-Lua runtime dependency: '+relative
for path in lua.rglob('*.lua'):
    text=path.read_text(encoding='utf-8')
    for module in re.findall(r'require\s*\(?\s*["\']((?:waterWorks|B47ANCEDWaterworks)/[^"\']+)["\']',text):
        targets=[lua/side/(module+'.lua')for side in ['shared','client','server']]
        assert any(target.is_file()and target.relative_to(mod).as_posix() in seen.values()for target in targets), 'unresolved/case-wrong import: '+module
translations={}
for path in (lua/'shared/Translate/EN').glob('*.json'):
    data=json.loads(path.read_text(encoding='utf-8'));assert not translations.keys()&data.keys(),'duplicate translation keys'
    translations.update(data)
assert translations['Sandbox_waterWorks']==inv['display_name']
for file,key,suffix in [('NetworkInspector','UI_B47ANCEDWaterworks_NetworkInspector',' Network Inspector'),('SamplingClient','UI_B47ANCEDWaterworks_WaterSample',' Water Sample')]:
    assert translations[key]==inv['display_name']+suffix
    assert key in (lua/'client/waterWorks'/(file+'.lua')).read_text(encoding='utf-8')
options=(mod/'42/media/sandbox-options.txt').read_text(encoding='utf-8')
for key in re.findall(r'translation\s*=\s*([A-Za-z0-9_]+)',options):assert 'Sandbox_'+key in translations, 'missing sandbox label: '+key
# New content keys follow the installed Build 42 raw item/recipe JSON format.
for key in ['Register','Install','Replace','Capacity','Empty','Recovery','Hazards','Filter','LastFailed']:
    assert 'UI_B47ANCEDWaterworks_Sediment'+key in translations, 'missing sediment action label: '+key
for name in ['SedimentFilterHousing','SedimentFilterMedia']:
    assert 'waterWorks.'+name in translations, 'missing raw item translation: '+name
    assert 'Assemble'+name in translations, 'missing raw recipe translation: '+name
content=(mod/'42/media/scripts/B47ANCEDWaterworks_Items.txt').read_text(encoding='utf-8')
assert re.search(r'item 1 \[Base\.Sandbag\] flags\[ItemCount;IsFull\] mode:destroy',content), 'cartridge must consume a whole full sandbag'
for name in ['SedimentFilterHousing','SedimentFilterMedia']:
    assert re.search(r'craftRecipe Assemble'+name+r'\s*\{',content), 'missing recipe: '+name
    assert 'item 1 waterWorks.'+name in content, 'missing recipe output: '+name
# Portable implementation of the documented hub source digest contract.
overview=json.loads((root/'docs/MOD_OVERVIEW.json').read_text(encoding='utf-8'))
assert overview['schema']==1 and overview['id']=='water' and overview['reviewed'] is True
assert overview['version']==(root/'VERSION').read_text(encoding='utf-8').strip()
digest=hashlib.sha256();inputs=[root/'README.md',root/'VERSION']
for source in ['src','Contents/mods']:
    base=root/source
    if base.is_dir():inputs.extend(p for p in base.rglob('*')if p.is_file())
assert len(inputs)<=20000, 'overview source file budget exceeded'
for path in sorted(set(inputs),key=lambda p:p.as_posix()):
    if path.suffix.lower()not in {'.lua','.txt','.json','.md','.info',''}:continue
    assert not path.is_symlink() and path.stat().st_size<=10000000, 'unsafe overview source'
    digest.update(path.relative_to(root).as_posix().encode());digest.update(b'\0')
    digest.update(hashlib.sha256(path.read_bytes()).digest())
assert digest.hexdigest()==overview['source_digest'], 'overview review is stale; refresh after source/README/VERSION edits'
for evidence in overview['evidence']:
    relative=Path(evidence);assert not relative.is_absolute() and '..'not in relative.parts and (root/relative).is_file(), 'unsafe/missing overview evidence'
print('PASS sediment content/localization and reviewed overview source/version binding')
workshop=(root/'workshop.txt').read_text(encoding='utf-8')
body='\n'.join(line[len('description='):]for line in workshop.splitlines()if line.startswith('description='))
assert body.rstrip()==(root/'WORKSHOP_DESCRIPTION.txt').read_text(encoding='utf-8').rstrip(), 'Workshop body/source drift'
assert '\\n' not in workshop and '\n\n' in body, 'Workshop paragraph corruption'
assert 'visibility=public' in workshop
assert 'Internal Mod ID: '+inv['mod_id'] in (mod/'info.txt').read_text(encoding='utf-8')
for p in [mod/'42/mod.info',root/'WORKSHOP_DESCRIPTION.txt',root/'workshop.txt']:
    assert not re.search(r'(?m)^(?:name|id|title)=waterWorks$|(?:Mod ID: waterWorks$)',p.read_text(encoding='utf-8')), 'stale activation identity'
proof=json.loads((root/'docs/rename-0.34.0-provenance.json').read_text(encoding='utf-8'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
checked_protected=0
for path,digest in proof['protected_files'].items():
    if not (root/path).exists() and path in inv['local_only_historical']:
        print('LOCAL HISTORY NOT PRESENT (excluded from Git): '+path)
        continue
    assert sha(root/path)==digest, 'protected bytes changed: '+path
    checked_protected+=1
dist={p.relative_to(root).as_posix():sha(p)for p in (root/'dist').rglob('*')if p.is_file()}
combined=hashlib.sha256(''.join(k+'\0'+v+'\n'for k,v in sorted(dist.items())).encode()).hexdigest()
if (root/'dist').exists():
    assert len(dist)==proof['historical_dist_file_count']and combined==proof['historical_dist_tree_sha256'], 'historical dist changed'
else:
    assert 'dist/' in inv['local_only_historical'], 'missing undeclared historical output'
    print('LOCAL HISTORY NOT PRESENT (excluded from Git): dist/; recorded hashes retained, archive bytes NOT CHECKED')
notes=(root/'WORKSHOP_CHANGE_NOTE.txt').read_bytes()
assert hashlib.sha256(notes[-proof['previous_changenote_bytes']:]).hexdigest()==proof['previous_changenote_sha256'], 'previous changenote changed'
for p in [root/'README.md',mod/'42/mod.info',root/'workshop.txt',root/'version-inventory.json']:
    text=p.read_text(encoding='utf-8');assert '\ufffd' not in text and 'B47ANCE\u00c3' not in text, 'branding encoding corruption'
print(f'PASS identity, translations, Lua-only layout, imports/case and Workshop paragraphs; {len(dist)} historical files and {checked_protected} present protected files unchanged')
subprocess.run([sys.executable,str(root/'scripts/run_lua_tests.py'),'--root',str(root)],check=True)
