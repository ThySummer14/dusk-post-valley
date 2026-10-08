"""Refresh static build metadata after an official Godot PCK export."""
from pathlib import Path
import hashlib,json,re,gzip
root=Path(__file__).resolve().parents[1];web=root/'docs'
pck=web/'index.pck';assert pck.read_bytes()[:4]==b'GDPC'
page=(web/'index.html').read_text();page,count=re.subn(r'"index.pck":\d+', '"index.pck":'+str(pck.stat().st_size),page);assert count==1;(web/'index.html').write_text(page)
wasm=gzip.decompress((web/'index.wasm.gz').read_bytes());assert hashlib.sha256(wasm).hexdigest()=='26b61ce95247012ab3dca3ff51e96d1cdbff44ee91a8c20a83e150afca83f1b6'
manifest={'game_version':'v0.3-r2','engine':'Godot4.6.3','threads':False,'engine_decoded_bytes':len(wasm),'engine_decoded_sha256':hashlib.sha256(wasm).hexdigest(),'files':[{'file':str(f.relative_to(web)),'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in sorted(web.rglob('*')) if f.is_file() and f.name!='build-manifest.json']}
(web/'build-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('Updated',pck.stat().st_size,'byte PCK and static asset manifest')
