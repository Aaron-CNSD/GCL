from pathlib import Path
import shutil,subprocess,plistlib,hashlib,json,sys,os
repo=Path(__file__).resolve().parents[1];engine=repo/'ios/build/engine';out=Path(sys.argv[1]).resolve();target=out/'ios/Payload/GCL.app';target.parent.mkdir(parents=True,exist_ok=True)
subprocess.run(['/usr/bin/ditto',str(engine/'artifacts/Payload/AngelAuraAmethyst.app'),str(target)],check=True)
info=plistlib.loads((target/'Info.plist').read_bytes());info.update(CFBundleDisplayName='GCL',CFBundleIdentifier='com.aarongame.gcl.ios',CFBundleShortVersionString='0.3.0',CFBundleVersion='3');(target/'Info.plist').write_bytes(plistlib.dumps(info))
licenses=target/'GCL-LICENSES';licenses.mkdir(exist_ok=True)
for name in ['LICENSE','CONTRIBUTORS.md']:shutil.copy2(repo/name,licenses/name)
shutil.copy2(repo/'ios/engine/README.upstream.md',licenses/'Amethyst-README.md')
for path in (repo/'ios/engine/Natives/external').rglob('*'):
 if path.is_file() and path.name.lower() in ['license','license.txt','license.md','copying','copying.txt','notice'] and '.git' not in path.parts:
  rel=path.relative_to(repo/'ios/engine/Natives/external');dest=licenses/'engine-third-party'/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,dest)
lock=[]
for archive in (engine/'depends').glob('jre*-release.tar.xz'):
 major=archive.name.split('-')[0].removeprefix('jre');lock.append({'java':major,'archive':archive.name,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'source':'https://assets.angelauramc.dev/openjdk/ios-arm64/jre'+major+'-ios-aarch64.zip'})
locked=json.loads((repo/'ios/runtime-lock.json').read_text())
assert {x['java']:x['sha256'] for x in lock}=={x['java']:x['sha256'] for x in locked},'Runtime lock mismatch'
shutil.copy2(repo/'ios/runtime-lock.json',licenses/'runtime-lock.json')
for major in ['8','17','21','25']:
 runtime=target/f'java_runtimes/java-{major}-openjdk'
 assert runtime.is_dir() and any(runtime.rglob('libjvm.dylib')),'Missing Java '+major
binary=target/info['CFBundleExecutable'];assert binary.is_file()
subprocess.run(['/usr/bin/codesign','--force','--deep','--sign','-','--entitlements',str(repo/'ios/entitlements.plist'),'--generate-entitlement-der',str(target)],check=True)
subprocess.run(['/usr/bin/codesign','--verify','--deep','--strict',str(target)],check=True)
ipa=out/'GCL-0.3.0-iOS.ipa'
subprocess.run(['/usr/bin/ditto','-c','-k','--keepParent',str(target.parent),str(ipa)],check=True)
print('PACKAGED '+str(ipa),flush=True)
