# v0.3.0 release preparation

Implemented: smaller window; matching side/launch material; sidebar instance chooser; legacy/26.x version support; update notes/history and manual rollback package downloads; own LAN server implementation and house icon; new website source. Terracotta runtime was removed.

Validated: universal macOS build and ad-hoc signature; LAN options consent, operators, online-mode properties, invalid administrator/port rejection, supported version parsing, offline UUID.

Pending before publication: run the new app and review room/settings/update-history UI; explicitly user-accepted Minecraft EULA before testing a real server; server readiness/stop and two-device LAN join; release metadata/assets and source commit/push; Cloudflare deployment and online page verification. Never describe these pending items as completed. Release number reserved locally: v0.3.0; User explicitly requested v0.3.0; the existing draft must be archived before replacing it with this Mac release.

Website source: website/index.html, icon.png, scenery.jpg. Production worker is in ../GlassDeck/deploy/wrangler.jsonc and serves ../GlassDeck/website. Copy the new GCL root assets only, preserving unrelated /app, /glassdeck and guides.
