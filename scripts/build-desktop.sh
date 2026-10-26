#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:-$PWD/artifacts/desktop}"
mkdir -p "$out" desktop/build/classes desktop/build/jar
jdk="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
if [ -n "$jdk" ]; then export PATH="$jdk/bin:$PATH"; fi
javac --release 17 -encoding UTF-8 -cp desktop/lib/gson-2.13.1.jar -d desktop/build/classes desktop/src/dev/aarongame/gcl/*.java
cp -R desktop/build/classes/. desktop/build/jar/
(cd desktop/build/jar && jar xf ../../lib/gson-2.13.1.jar)
rm -f desktop/build/jar/META-INF/*.SF desktop/build/jar/META-INF/*.RSA desktop/build/jar/META-INF/MANIFEST.MF
cp LICENSE desktop/lib/NOTICE.txt desktop/lib/LICENSE-APACHE-2.0.txt desktop/build/jar/
cp macos/Assets/GCL-preview.png desktop/build/jar/GCL.png
printf 'Manifest-Version: 1.0\nMain-Class: dev.aarongame.gcl.Launcher\nImplementation-Version: 0.3.0\n\n' > desktop/build/manifest.mf
jar cfm "$out/GCL-0.3.0-Desktop.jar" desktop/build/manifest.mf -C desktop/build/jar .
