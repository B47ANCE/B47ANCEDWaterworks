"""Audit every indexed file before public pushes; never print suspected credential values."""
import argparse,re,subprocess
from pathlib import Path,PurePosixPath

ROOT=Path(__file__).resolve().parents[1]
PATTERNS={
    'GitHub token':r'(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})',
    'OpenAI key':r'sk-(?:proj-)?[A-Za-z0-9_-]{20,}',
    'AWS access key':r'AKIA[0-9A-Z]{16}',
    'private key':r'-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----',
    'credential assignment':r"""(?i)\b(?:password|api[_-]?key|access[_-]?token|client[_-]?secret)\s*[:=]\s*["']([^"'\s]{8,})["']""",
}

def run():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--staged',action='store_true',help='Audit the complete index, including all staged changes.');parser.parse_args()
    paths=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode('utf-8').split('\0')
    issues=[];count=0
    for name in filter(None,paths):
        path=PurePosixPath(name);parts={part.lower()for part in path.parts}
        if parts&{'.agents','.codex','dist','__pycache__','_ci_dependencies'} or path.suffix.lower() in {'.log','.pem','.key','.pfx','.p12','.pyc','.zip'} or path.name.lower().startswith(('.env','server-console','console.txt','.steamcmd-')) or path.name.lower()=='local.settings.json':
            issues.append((name,'forbidden public path',0));continue
        data=subprocess.check_output(['git','show',':'+name],cwd=ROOT);count+=1
        if b'\0' in data:
            if path.suffix.lower() not in {'.png','.jpg','.jpeg','.gif','.webp'}:issues.append((name,'unexpected binary',0))
            continue
        try:text=data.decode('utf-8-sig')
        except UnicodeDecodeError:issues.append((name,'non-UTF-8 text',0));continue
        for label,pattern in PATTERNS.items():
            for match in re.finditer(pattern,text):issues.append((name,label,text.count('\n',0,match.start())+1))
    for name,label,line in issues:print(f'{name}:{line}: {label}; value omitted')
    print(f'Public index audit: {count} files, {len(issues)} findings')
    return bool(issues)
if __name__=='__main__':raise SystemExit(run())
