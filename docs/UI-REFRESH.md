# v0.2.0 interface refresh

Based on `3447ced`, retaining the v0.2.0 game engine and functional pages. The current UI follows the user's HMCL reference: grouped left navigation, open background space and a bottom-right launch control.

- The sidebar has a 26-point rounded glass outline, with 12-point inset from the window edge.
- Launch and version selection share one 24-point rounded glass outline. Both hit targets are exactly 76 points high; the arrow segment is narrower, as in the reference. The group sits 16 points from the content's right and bottom edges.
- The instance name appears beneath version management in the sidebar. Redundant home title/version cards were removed to keep the scene open.
- A labeled **更换背景** button at the top right directly opens the image/video picker. PNG, JPEG, MP4 and MOV imports are copied into the user's GCL background folder. Both normal and isolated preview builds remember the selected path on relaunch.
- Background settings include fit/fill, display strength and blur. Native video playback is muted and pauses when inactive or Reduce Motion is enabled.
- The rejected automatic Minecraft panorama has been removed. No unsolicited game scenery or third-party picture is bundled or selected. Without a chosen background the window uses system vibrancy.
- macOS 26 uses native glass surfaces; older systems fall back to system materials. Navigation and page transitions respect Reduce Motion, and panels respect Reduce Transparency.
- The workbench icon is an original editable SVG. HMCL/PCL/FCL assets and the user's reference screenshot are not bundled.

`GCLDemoMode` keeps game data in a temporary directory and starts with generic Player. It preserves appearance/background preferences so the preview can be used to review customization. Public screenshots still require checking for personal data and user-supplied backgrounds.

Validation: the current revision compiled for Apple Silicon and Intel, and the universal app passed signature verification. Fresh UI verification awaits the required run confirmation. Compilation does not establish gameplay compatibility or measured animation frame rate.
