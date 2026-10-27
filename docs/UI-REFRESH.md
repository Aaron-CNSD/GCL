# v0.2.0 HMCL-style refresh

Based on `3447ced`; the v0.2.0 game engine and functional pages remain unchanged.

- Restrained blue header, full-height flat translucent sidebar, small-radius controls, and same-height joined launch/version controls at the bottom right.
- The built-in background is HMCL's unchanged `2021-08-26.jpg`, visually matched to the user's birch-coast/sheep reference. It is packaged in the app for offline use and needs no installed Minecraft assets or network connection.
- User-selected PNG/JPEG/MP4/MOV backgrounds override the built-in image. Restore built-in background, fit/fill, display strength and blur remain available. Native video playback is muted and pauses when inactive or Reduce Motion is enabled.
- Native Mac title-bar controls and the original GCL workbench icon are retained. The product is named GCL, not HMCL.
- Source, SHA-256 and upstream license are preserved in `docs/third-party/HMCL-WALLPAPER.md` and `HMCL-LICENSE.txt`, included in the app. The About page links to the wallpaper source.

Validation (2026-10-27): after explicit user approval, official image download and preview launch succeeded. The native screenshot confirmed the packaged birch-coast scene, flat sidebar, blue header and matching-height launch controls. Apple Silicon and Intel compilation and app signature checks passed. The packaged background was compared byte-for-byte with the source and the license file was confirmed present. This pass did not test Minecraft entering a world or measure animation frame rate. No release or website deployment was performed.
