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

Validation: the current revision compiled for Apple Silicon and Intel, and the universal app passed signature verification. The user approved running this revision. The native preview was opened and its screenshot confirmed the inset rounded sidebar and equal-height joined launch controls. The labeled background button opened the expected PNG/JPEG/MP4/MOV picker; it was left open for the user to choose their own file. Import persistence was not tested in this pass. Compilation does not establish gameplay compatibility or measured animation frame rate.

## Current HMCL-style revision (in progress)

The user requested the actual HMCL built-in wallpaper and a less rounded interface. The revision adds a restrained blue header, a full-height rectangular sidebar and small-radius controls. Background replacement remains available; resetting a custom background returns to the bundled `DefaultBackground.jpg`.

Apple Silicon compilation passed. The background loader and packaging hook are implemented, but the image is not bundled yet: the browser download gate explicitly reported that permission to download from GitHub was declined. Do not replace this missing file with a crop from the user's reference screenshot, retrieve it through a different download channel, or publish a package claiming to contain it. Obtain fresh explicit permission before downloading the official wallpaper. Its source/attribution must be recorded when the correct image is confirmed.
