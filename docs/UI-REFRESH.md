# GCL compact glass refresh

Default content size: 880×550 points; minimum: 820×520. The 36-point glass header, inset glass sidebar, teal accent and smaller joined launch control replace the solid indigo layout. Native macOS 26 glass is used with material fallback and Reduce Transparency support. Existing scenery and content-center functions are retained.

Responsiveness changes: page navigation no longer animates entire glass pages or uses matched geometry. Press feedback has no timed animation. Background video is isolated from unrelated Model updates, pauses on content pages and inactive windows, and resumes using the existing player. AVPlayerLayer layout disables implicit layer animations. Playback commands are only sent when pause state changes; choosing a new video resets playback state.

Validation: Apple Silicon/Intel compilation and signature/whitespace checks. The preview was launched and inspected: native glass header/sidebar/launch control rendered, and navigation to the content center plus its loader tab completed successfully. Perceived latency was not benchmarked; no quantitative latency improvement is claimed. No public release or deployment.
