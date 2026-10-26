"""Prepare portable, self-contained Windows/Linux bundles with checksum-verified Temurin."""
from pathlib import Path
import json,urllib.request,hashlib,zipfile,tarfile,shutil,concurrent.futures,sys
repo=Path(__file__).resolve().parents[1]
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
def read(url):
 with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'GCL/0.3.0 (Aaron-CNSD/GCL)'}),timeout=180) as r:return r.read()
def build(os):
 arch='x64';assets=json.loads(read(f'https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture={arch}&image_type=jre&os={os}&vendor=eclipse'))
 pkg=assets[0]['binary']['package'];name=f'GCL-0.3.0-{os}-x64';stage=out/name;stage.mkdir(exist_ok=True)
 archive=out/pkg['name']
 if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest()!=pkg['checksum']:
  data=read(pkg['link']);assert hashlib.sha256(data).hexdigest()==pkg['checksum'];archive.write_bytes(data)
 unpack=out/(name+'-runtime');unpack.mkdir(exist_ok=True)
 if os=='windows':
  with zipfile.ZipFile(archive) as z:z.extractall(unpack)
 else:
  with tarfile.open(archive) as t:t.extractall(unpack,filter='data')
 runtime=next(p for p in unpack.iterdir() if p.is_dir())
 if (stage/'runtime').exists():shutil.rmtree(stage/'runtime')
 shutil.copytree(runtime,stage/'runtime',symlinks=True)
 for filename in ['GCL-0.3.0-Desktop.jar']:shutil.copy2(out/filename,stage/filename)
 for filename in ['LICENSE','CONTRIBUTORS.md']:shutil.copy2(repo/filename,stage/filename)
 shutil.copytree(repo/'desktop/lib',stage/'third-party',dirs_exist_ok=True)
 (stage/'runtime-source.json').write_text(json.dumps({'distribution':'Eclipse Temurin','version':assets[0]['version']['semver'],'url':pkg['link'],'sha256':pkg['checksum']},indent=2))
 (stage/'README.txt').write_text('GCL 0.3.0 development preview\n'+('Double-click Start-GCL.cmd.\n' if os=='windows' else 'Run ./start-gcl.sh on a graphical Linux desktop.\n')+'Bundled Java 17 starts the launcher. Game Java is downloaded as needed.\nVanilla / Fabric / Quilt. Real-world gameplay has not been verified on Windows/Linux.\nLocal usernames cannot access Realms or servers requiring Microsoft authentication.\nSource: https://github.com/Aaron-CNSD/GCL\n')
 if os=='windows':
  (stage/'Start-GCL.cmd').write_bytes(b'@echo off\r\ncd /d "%~dp0"\r\n"%~dp0runtime\\bin\\javaw.exe" -jar "%~dp0GCL-0.3.0-Desktop.jar"\r\n')
  shutil.make_archive(str(out/name),'zip',out,name)
 else:
  launch=stage/'start-gcl.sh';launch.write_text('#!/bin/sh\nset -eu\nGCL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nexec "$GCL_DIR/runtime/bin/java" -jar "$GCL_DIR/GCL-0.3.0-Desktop.jar" "$@"\n');launch.chmod(0o755)
  with tarfile.open(out/(name+'.tar.gz'),'w:gz') as t:t.add(stage,arcname=name)
 print('PACKAGED '+name,flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(build,['windows','linux']))
