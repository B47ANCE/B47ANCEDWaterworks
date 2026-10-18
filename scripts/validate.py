"""Validate active identity, compatibility surfaces and protected historical bytes offline."""
from pathlib import Path
import hashlib,json,re,struct,subprocess,sys,zlib
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
art=json.loads((root/'docs/artwork-provenance.json').read_text(encoding='utf-8'))
art_paths={'preview.png',inv['source_root']+'/thumbnail.png'}
assert art['schema']==1 and set(art['current_files'])==art_paths
relocations=art['historical_relocations']
assert art['icon']==inv['source_root']+'/42/icon.png'
assert set(relocations)==art_paths|{art['icon']}, 'only explicitly replaced artwork may relocate history'
for path in relocations.values():
    relative=Path(path)
    assert not relative.is_absolute() and '..'not in relative.parts and path.startswith('assets/artwork/history/'), 'unsafe artwork history path'
def png_dimensions(path):
    data=path.read_bytes();assert data[:8]==b'\x89PNG\r\n\x1a\n', 'invalid PNG signature'
    offset=8;dimensions=None;has_data=False;finished=False
    while offset<len(data):
        assert offset+12<=len(data), 'truncated PNG chunk'
        length=struct.unpack('>I',data[offset:offset+4])[0];end=offset+12+length
        assert end<=len(data), 'truncated PNG payload'
        kind=data[offset+4:offset+8];payload=data[offset+8:end-4]
        assert zlib.crc32(kind+payload)&0xffffffff==struct.unpack('>I',data[end-4:end])[0], 'PNG CRC mismatch'
        if dimensions is None:
            assert kind==b'IHDR'and length==13, 'PNG must start with IHDR'
            dimensions=list(struct.unpack('>II',payload[:8]));assert min(dimensions)>0
        if kind==b'IDAT':has_data=True
        offset=end
        if kind==b'IEND':
            assert length==0 and offset==len(data), 'invalid PNG end/trailing data'
            finished=True;break
    assert finished and has_data, 'incomplete PNG'
    return dimensions
for path in art_paths:
    assert sha(root/path)==art['source']['sha256'], 'current artwork bytes differ from supplied source'
    assert png_dimensions(root/path)==art['source']['dimensions'], 'current artwork dimensions differ'
icon_source=art['icon_source']
assert icon_source['master']=='assets/artwork/waterworks-icon-transparent.png'
for path in [art['icon'],icon_source['master']]:
    assert sha(root/path)==icon_source['sha256'], 'icon differs from approved transparent source'
    assert png_dimensions(root/path)==icon_source['dimensions'], 'icon dimensions differ'
    assert (root/path).read_bytes()[25]==6, 'icon must retain RGBA alpha'
assert (root/icon_source['prompt']).is_file(), 'missing icon authoring prompt'
print('PASS approved RGBA icon, unchanged thumbnail/preview, PNG CRCs/dimensions and artwork history')
checked_protected=0
for path,digest in proof['protected_files'].items():
    if not (root/path).exists() and path in inv['local_only_historical']:
        print('LOCAL HISTORY NOT PRESENT (excluded from Git): '+path)
        continue
    assert sha(root/relocations.get(path,path))==digest, 'protected historical bytes changed: '+path
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
print(f'PASS identity, translations, Lua-only layout, imports/case and Workshop paragraphs; {len(dist)} historical files and {checked_protected} protected history records verified')
subprocess.run([sys.executable,str(root/'scripts/run_lua_tests.py'),'--root',str(root)],check=True)
