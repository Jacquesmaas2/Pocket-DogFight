# Pocket Dogfight Web Deployment

## Architecture

```
Godot source (this repo, Godot 4.3, GL Compatibility renderer)
    ↓  push to main / manual run
GitHub Actions  (.github/workflows/deploy-godot-web.yml)
    ↓  godot --headless --export-release Web build/web/index.html
Godot Web export  (single-threaded WASM, no cross-origin-isolation headers needed)
    ↓  actions/upload-pages-artifact (build/web only)
GitHub Pages  (static client)
    ↓
Browser (desktop + mobile, landscape touch controls)
```

`build/` is generated output and is git-ignored. The source tree is never published; the Pages artifact contains only `build/web`.

## Automatic deployment

Every push to `main` runs the workflow: it reads the Godot version from `project.godot` (`config/features` → `4.3-stable`), downloads the matching Linux editor and Web export templates (cached), exports the `Web` preset from `export_presets.cfg`, fails if `index.html` / `index.wasm` / `index.pck` are missing, and deploys the artifact to the `github-pages` environment.

## Manual deployment

GitHub → **Actions** → *Deploy Godot Web build to GitHub Pages* → **Run workflow** → branch `main`.

Local equivalent: `.\tools\export_web.ps1` produces the same `build/web`.

## GitHub Pages configuration (one-time, manual)

1. This repository is connected to GitHub at `https://github.com/Jacquesmaas2/Pocket-DogFight` on branch `main`.
2. Repository → **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. (First run only) Settings → Actions → General → Workflow permissions: *Read and write* is **not** required; the workflow declares `pages: write` + `id-token: write` itself.

The site URL will be `https://<owner>.github.io/<repo>/` (project site). The export uses relative paths (`index.js`, `index.pck`, `index.wasm`), so the sub-path works without configuration.

## Local Web test

```powershell
.\tools\export_web.ps1          # → build/web
.\tools\serve_web.ps1           # http://localhost:8080/  (never open index.html via file://)
```
Any static HTTP server works too, e.g. `python -m http.server 8080 --directory build/web`.
Optional: `.\tools\serve_web.ps1 -Tunnel -Server wss://<game-server>` prints a public test URL via cloudflared.

Deep link: `https://<pages-url>/?server=wss://host:port` pre-fills and opens the Join dialog.

## Multiplayer

### Online hosting system (how PLAY ONLINE works)

```
Browser client (GitHub Pages)  --wss-->  dedicated server (Docker on Render/another host, or your laptop + tunnel)
         ^ reads build/web/server.txt  <--  written by the deploy workflow from repo variable DEFAULT_SERVER_URL
```

1. **Run a server** (pick one):
    - **Cloud server:** Render: *New → Blueprint* on this repo ([render.yaml](render.yaml)); address `wss://<service>.onrender.com`. The free tier may sleep while idle. This server is separate from GitHub Pages and requires your own Render account; Pages itself serves only the Godot Web client.
   - **Laptop:** `.\tools\go_online.ps1` starts server + cloudflared tunnel and copies the share link to the clipboard (address changes on every restart).
2. **Tell the web client:** GitHub → Settings → Secrets and variables → Actions → **Variables** → `DEFAULT_SERVER_URL = wss://<your-server>` → re-run the deploy workflow. `server.txt` is published next to `index.html`; the big **PLAY ONLINE** button connects there. Native builds use `PD_DEFAULT_SERVER` env or `pocket_dogfight/default_server` in `project.godot`.
3. Share links always work regardless: `<pages-url>/?server=wss://…` (the lobby has a **Copy** button).

The dedicated server waits for 2 pilots, shows a 12 s countdown in everyone's lobby, starts the match, lets late joiners drop in, and returns to the waiting state when the last player leaves.

### Status

| Status | Functionality |
|---|---|
| **WORKING** | Offline Quick Match vs bots, full Story mode (6 missions), settings persistence (IndexedDB via `user://`) |
| **WORKING** | Joining a game server over **WebSocket** (`ws://` on http, `wss://` required from the https Pages site). Same gameplay/authority code as native. |
| **REQUIRES EXTERNAL SERVICE** | The game server itself. GitHub Pages hosts only the static client. Run `tools/run_server.ps1` (headless dedicated server, WebSocket) on a laptop/VPS and expose it with TLS, e.g. `tools/start_tunnel.ps1` (cloudflared → `wss://…trycloudflare.com`). Share `<pages-url>/?server=wss://…`. |
| **NOT AVAILABLE IN BROWSER** | Hosting from the browser (no listening sockets) — the Host button is hidden; ENet/UDP transport. |
| **NOT YET IMPLEMENTED** | WebRTC peer-to-peer (`webrtc://`). `NetworkManager` reserves `TRANSPORT_WEBRTC` and reads `PD_SIGNALING_URL` / `PD_ICE_SERVERS` (JSON array of ICE server dicts) as configuration points; a signaling server and STUN/TURN are separate services and are not provided by this repository or by GitHub Pages. No credentials are committed. |

## Troubleshooting

- **Blank page / spinner forever** – open DevTools console. `index.wasm` 404 → export did not finish or Pages source is not "GitHub Actions". Opened via `file://` → use an HTTP server.
- **"SharedArrayBuffer is not defined"** – threads were enabled. The `Web` preset must keep `variant/thread_support=false` (GitHub Pages cannot send COOP/COEP headers).
- **Export fails in Actions: "No export template found"** – template version mismatch. The workflow derives the version from `project.godot`; if you upgrade Godot, keep `config/features` in sync and clear the Actions cache (`godot-<version>-linux-web`).
- **Export fails: renderer** – the project uses `gl_compatibility` for all platforms; do not switch to Forward+/Mobile for Web.
- **Assets missing on Pages but fine locally** – a hard-coded absolute URL was introduced. Godot's exporter emits relative paths; keep `html/custom_html_shell` empty or relative.
- **Join fails from Pages** – https pages may only open `wss://` (not `ws://`). Check the server tunnel is running and the URL has no trailing slash issues; the browser build cannot use `enet://`.
- **Touch controls missing** – they appear when a touchscreen is detected; force them in Settings → "Force touch controls".
- **Audio silent on mobile** – browsers need a user gesture first; tap once (the menu click counts).
