#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:-artifacts/macos}"
mkdir -p "$out/GCL.app/Contents/MacOS" "$out/GCL.app/Contents/Resources"
for arch in arm64 x86_64; do
 swiftc -module-cache-path /private/tmp/glasscraft-module-cache -parse-as-library -O -target "$arch-apple-macosx13.0" macos/*.swift -o "$out/GCL-$arch"
done
lipo -create "$out/GCL-arm64" "$out/GCL-x86_64" -output "$out/GCL.app/Contents/MacOS/GCL"
cp macos/Info.plist "$out/GCL.app/Contents/Info.plist"
cp macos/Assets/GCL.icns "$out/GCL.app/Contents/Resources/GCL.icns"
cp macos/Assets/GCL-preview.png "$out/GCL.app/Contents/Resources/GCLIcon.png"
cp LICENSE CONTRIBUTORS.md "$out/GCL.app/Contents/Resources/"
mkdir -p "$out/GCL.app/Contents/Resources/ThirdParty"
cp docs/third-party/* "$out/GCL.app/Contents/Resources/ThirdParty/"
codesign --force --deep --sign - "$out/GCL.app"
ditto -c -k --sequesterRsrc --keepParent "$out/GCL.app" "$out/GCL-macOS-universal.zip"
