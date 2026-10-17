from pathlib import Path
import argparse,json,re

def check(root):
    inventory=json.loads((root/'version-inventory.json').read_text(encoding='utf-8'))
    version=(root/inventory['canonical']).read_text(encoding='utf-8').strip()
    assert re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+",version), 'canonical version must be SemVer'
    for name,pattern in inventory['mirrors'].items():
        match=re.search(pattern,(root/name).read_text(encoding='utf-8-sig'))
        assert match and match.group(1)==version, 'version mismatch: '+name
    info=(root/inventory['source_root']/'42/mod.info').read_text(encoding='utf-8')
    for key,value in [('id',inventory['mod_id']),('name',inventory['display_name'])]:
        assert re.search('(?m)^'+key+'='+re.escape(value)+'$',info), 'identity mismatch: '+key
    assert (root/'WORKSHOP_ID.txt').read_text().strip()==inventory['workshop_id'], 'Workshop identity mismatch'
    workshop=(root/'workshop.txt').read_text(encoding='utf-8')
    assert 'title='+inventory['display_name']+'\n' in workshop
    assert 'description=Mod ID: '+inventory['mod_id'] in workshop
    print('PASS canonical version '+version+': '+str(len(inventory['mirrors']))+' current mirrors, mod and Workshop identity')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--release',action='store_true');args=parser.parse_args()
    if args.release: parser.error('Release validation BLOCKED: no current package/provenance or dedicated G7 evidence; this checker validates development source only.')
    check(args.root.resolve())
