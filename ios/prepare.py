from pathlib import Path
import shutil,plistlib,subprocess,json
repo=Path(__file__).resolve().parents[1];source=repo/'ios/engine';target=repo/'ios/build/engine'
if not (target/'Makefile').exists():shutil.copytree(source,target,ignore=shutil.ignore_patterns('.git','build','artifacts','depends','macos'),dirs_exist_ok=True)
shutil.copy2(repo/'ios/overlays/LauncherNewsViewController.m',target/'Natives/LauncherNewsViewController.m')
p=target/'Natives/Info.plist';info=plistlib.loads(p.read_bytes());info.update(CFBundleDisplayName='GCL',CFBundleIdentifier='com.aarongame.gcl.ios',CFBundleShortVersionString='0.3.0',CFBundleVersion='3');p.write_bytes(plistlib.dumps(info))
menu=target/'Natives/LauncherMenuViewController.m';s=menu.read_text();s=s.replace('UIImageView *titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AppLogo"]];','UIImageView *titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"GCLIcon.png"]];\n    titleView.frame=CGRectMake(0,0,90,42);');s=s.replace('    [titleView sizeToFit];','');menu.write_text(s)
resources=target/'Natives/resources';shutil.copy2(repo/'macos/Assets/GCL-preview.png',resources/'GCLIcon.png');licenses=resources/'GCL-LICENSES';licenses.mkdir(exist_ok=True);shutil.copy2(repo/'LICENSE',licenses/'GCL-GPL-3.0.txt');shutil.copy2(source/'LICENSE',licenses/'Amethyst-GPL-3.0.txt');shutil.copy2(repo/'CONTRIBUTORS.md',licenses/'CONTRIBUTORS.md')
(licenses/'engine-source.json').write_text(json.dumps({'source':'https://github.com/Aaron-CNSD/GlassCraft-iOS','upstream':'https://github.com/AngelAuraMC/Amethyst-iOS','commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=source,text=True).strip(),'overlay':'https://github.com/Aaron-CNSD/GCL/tree/main/ios'},indent=2))
# Icons are replaced in every asset variant, retaining the SDK-generated filename mapping.
for asset in (target/'Natives/Assets.xcassets').glob('AppIcon*.appiconset'):
 contents=json.loads((asset/'Contents.json').read_text())
 for image in contents.get('images',[]):
  if image.get('filename'):
   size=round(float(image['size'].split('x')[0])*float(image.get('scale','1x')[:-1]));dest=asset/image['filename']
   subprocess.run(['/usr/bin/sips','-z',str(size),str(size),str(repo/'macos/Assets/GCL-preview.png'),'--out',str(dest)],check=True,stdout=subprocess.DEVNULL)
print(target)
