#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
repo="$PWD"
out="${1:-$repo/artifacts/ios}"
: "${GCL_JDK8_HOME:?Set GCL_JDK8_HOME to a full macOS JDK 8 (not a JRE)}"
[ -x "$GCL_JDK8_HOME/bin/javac" ] || { echo 'JDK 8 javac is missing'; exit 1; }
command -v cmake >/dev/null
command -v python3 >/dev/null
git submodule update --init ios/engine
git -C ios/engine submodule update --init --depth 1 Natives/external/AFNetworking Natives/external/DBNumberedSlider Natives/external/fishhook Natives/external/MobileGlues
git -C ios/engine/Natives/external/MobileGlues submodule update --init --depth 1 src/main/cpp/3rdparty/glm src/main/cpp/3rdparty/xxhash src/main/cpp/include/FastSTL
python3 ios/prepare.py
python3 - <<'PY'
from pathlib import Path
import shutil
repo=Path.cwd();p=repo/'ios/build/engine/Makefile';s=p.read_text();cmake=shutil.which('cmake');signer=str(repo/'scripts/ios-adhoc-sign.py')
s=s.replace('cmake ',cmake+' ').replace('ldid ',signer+' ').replace('METHOD_DEPCHECK,ldid)',f'METHOD_DEPCHECK,{signer} --version)')
s=s.replace('ASSEMBLY_EXCEPTION,bin,include,jre,legal,LICENSE,man,THIRD_PARTY_README,','bin,include,jre,man,');p.write_text(s)
PY
make -C ios/build/engine native java JOBS=4 "BOOTJDK=$GCL_JDK8_HOME/bin"
make -C ios/build/engine jre assets JOBS=4 "BOOTJDK=$GCL_JDK8_HOME/bin"
python3 - <<'PY'
from pathlib import Path
import json,hashlib
for item in json.loads(Path('ios/runtime-lock.json').read_text()):
 p=Path('ios/build/engine/depends')/item['archive']
 assert hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],'iOS runtime differs from committed lock: '+item['archive']
print('Verified pinned iOS runtime archives')
PY
make -C ios/build/engine payload JOBS=4 "BOOTJDK=$GCL_JDK8_HOME/bin"
python3 scripts/package-ios.py "$out"
