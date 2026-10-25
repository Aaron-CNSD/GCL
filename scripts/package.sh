#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:-$PWD/artifacts/release}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
bash macos/build.sh "$out"
task_jdk="$(/usr/libexec/java_home -v 17)"
stage="$(mktemp -d /private/tmp/gcl-package.XXXXXX)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/jar" "$stage/dmg"
"$task_jdk/bin/javac" --release 8 -encoding UTF-8 -d "$stage/jar" bootstrap/GCLBootstrap.java
cp "$out/GCL-macOS-universal.zip" "$stage/jar/GCL-native.zip"
shasum -a 256 "$stage/jar/GCL-native.zip" | awk '{print $1}' > "$stage/jar/GCL-native.sha256"
printf 'Manifest-Version: 1.0\nMain-Class: GCLBootstrap\nImplementation-Title: GCL macOS Entry Point\nImplementation-Version: 0.7.0\n\n' > "$stage/manifest.mf"
cp LICENSE CONTRIBUTORS.md "$stage/jar/"
"$task_jdk/bin/jar" cfm "$out/GCL-0.7.0-macOS.jar" "$stage/manifest.mf" -C "$stage/jar" .
ditto "$out/GCL.app" "$stage/dmg/GCL.app"
ln -s /Applications "$stage/dmg/Applications"
printf 'GCL 0.7 开发预览\n将 GCL.app 拖入 Applications。macOS 13+，Apple Silicon / Intel。\n未经 Apple 公证，保留系统安全保护，按系统提示处理。\n完整进入世界与跨网联机尚未验证。\n项目：https://github.com/Aaron-CNSD/GCL\n' > "$stage/dmg/安装说明.txt"
hdiutil create -volname GCL -srcfolder "$stage/dmg" -ov -format UDZO "$out/GCL-0.7.0-macOS.dmg"
(cd "$out" && shasum -a 256 GCL-0.7.0-macOS.jar GCL-macOS-universal.zip GCL-0.7.0-macOS.dmg > SHA256SUMS.txt)
"$task_jdk/bin/java" -jar "$out/GCL-0.7.0-macOS.jar" --verify
codesign --verify --deep --strict "$out/GCL.app"
hdiutil verify "$out/GCL-0.7.0-macOS.dmg"
