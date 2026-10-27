# v0.2.0 interface refresh

This branch starts at `3447ced`, the v0.2.0 instance-workspace release. It does not import the rejected v0.3 interface or generated icon.

- Grouped left navigation, editable local player name, quiet home page, bottom-right launch button and version/configuration chooser.
- Existing v0.2.0 instance, loader, mod, resource, skin, room, settings and diagnostic actions remain connected to their original implementations.
- Original workbench SVG, rasterized for the application, app bundle and web icon. The HMCL/PCL/FCL images are references only and are not bundled.
- Optional local PNG/JPEG/MP4/MOV backgrounds. Video playback is native, muted and paused when inactive or Reduce Motion is enabled. No default third-party movie is included.
- `GCLDemoMode` uses a temporary game-data directory and generic Player account for screenshots. The normal app uses the existing GlassCraft application-support directory.

Icon source: `macos/Assets/GCL.svg`. Run `node scripts/render-icons.cjs` with `sharp` installed and macOS `iconutil` available.

The local preview is not a published release. Window and navigation checks do not demonstrate Minecraft entering a world or multiplayer across devices.

Validation (2026-10-27): Apple Silicon and Intel compilation passed; the universal app signature was verified. The isolated native preview showed the workbench icon, grouped navigation and home launch control. The version/configuration popover opened, and the version-management page displayed the retained configuration, instance, loader and import controls. New instance creation and gameplay were not verified in this pass.

## Native glass and motion refinement

The accepted layout is unchanged. macOS 26 uses native glass surfaces and glass buttons; the home launch controls share a GlassEffectContainer. Navigation selection moves with matched geometry, pages fade with a five-point offset over 220 ms, and button press feedback uses a small scale change. All these animations are disabled under Reduce Motion. Reduce Transparency uses opaque panels; older macOS versions use system materials. Window vibrancy uses NSVisualEffectView behind-window blending, without screen capture. A frost/clear preference is available on macOS 26.

The isolated native preview was opened after user confirmation. The version popover and settings page opened, the frost/clear control was changed, and navigation returned to the home page. The home glass surfaces and controls were captured. This is not a frame-rate measurement or gameplay test.

The glass refinement compiled for Apple Silicon and Intel and passed app signature verification. Automatic approval initially required confirmation to run the local preview. The user explicitly approved running and checking it; the preview then opened successfully.
