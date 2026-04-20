[![qtmesh status](https://api.qtmesh.dev/v1/u/fernandotonon/p/ld-59-axon-signals/badges/qtmesh-status.svg)](https://qtmesh.dev)
[![qtmesh score](https://api.qtmesh.dev/v1/u/fernandotonon/p/ld-59-axon-signals/badges/qtmesh-score.svg)](https://qtmesh.dev)
[![qtmesh errors](https://api.qtmesh.dev/v1/u/fernandotonon/p/ld-59-axon-signals/badges/qtmesh-errors.svg)](https://qtmesh.dev)
[![qtmesh warnings](https://api.qtmesh.dev/v1/u/fernandotonon/p/ld-59-axon-signals/badges/qtmesh-warnings.svg)](https://qtmesh.dev)
[![qtmesh models](https://api.qtmesh.dev/v1/u/fernandotonon/p/ld-59-axon-signals/badges/qtmesh-models.svg)](https://qtmesh.dev)
[![qtmesh animations](https://api.qtmesh.dev/v1/u/fernandotonon/p/ld-59-axon-signals/badges/qtmesh-animations.svg)](https://qtmesh.dev)
[![qtmesh skeletons](https://api.qtmesh.dev/v1/u/fernandotonon/p/ld-59-axon-signals/badges/qtmesh-skeletons.svg)](https://qtmesh.dev)
[![qtmesh materials](https://api.qtmesh.dev/v1/u/fernandotonon/p/ld-59-axon-signals/badges/qtmesh-materials.svg)](https://qtmesh.dev)


[![QtMesh Cloud summary](https://qtmesh.dev/v1/u/fernandotonon/p/ld-59-axon-signals/badges/qtmesh-share-card.svg)](https://qtmesh.dev)


# Axon Signals (LD prototype)

Toggle myelin on a discrete axon (click segments). A simplified **membrane potential (mV) + ATP** model drives success: myelin segments decay Vm slowly; **Ranvier nodes** (gaps between sheaths, plus foot/brain ends) reset Vm to −55 mV and spend ATP. Pumps and ions appear **only** on those nodes. The pulse runs in the same view.

## Play in the browser (Web Dojo)

No install needed for players. The game is plain **QML + JavaScript**; [Web Dojo](https://clayground.mistergc.dev/webdojo/) runs Clayground as WebAssembly and loads your sources from a URL.

### After this repo is on GitHub

1. Push the repo (including the `qml/` folder).
2. Open Web Dojo with your **raw** `main.qml` URL (adjust user, repo, and branch):

   **https://clayground.mistergc.dev/webdojo/#clay-src=https://raw.githubusercontent.com/fernandotonon/LD-59-Axon-Signals/main/qml/main.qml**

   (Forks: replace `fernandotonon/LD-59-Axon-Signals` and branch `main` if yours differ.)

3. Click **Run** (or use **auto-reload** if you develop with [`clay-dev-server`](https://clayground.mistergc.dev/docs/getting-started/webdojo/)).

Relative imports (`js/signalSim.js`) resolve next to `main.qml` on that host; only `main.qml` + `qml/js/` are required for Web Dojo.

### Share a short link

With the game open in Web Dojo, use **Share** to pack the session into the URL, or **Standalone** for a minimal player-only view. Best for small snippets; for this multi-file project, the **raw GitHub** link above is usually more reliable.

### Embed with less chrome (optional)

Hash parameters are [documented here](https://clayground.mistergc.dev/docs/getting-started/webdojo/). Example:

`/webdojo/#clay-src=…&clay-hd=0&clay-ed=0&clay-con=0`

## Local desktop build

Requires Qt 6 (Quick, QuickControls2, QuickLayouts, Quick3D, Multimedia). From the repo root:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/AxonSignals
```

## Local Web Dojo development

Serve the `qml` folder, then open Web Dojo with `clay-src` pointing at your machine:

```bash
cd qml && python3 -m http.server 9000
```

**https://clayground.mistergc.dev/webdojo/#clay-src=http://127.0.0.1:9000/main.qml**

For live reload, use `pip install clay_dev_server` and `clay-dev-server`, then **Connect** from the Dev Server pane in Web Dojo (see the same docs page).

## Pre-render 3D Models To PNG Turntables

Web Dojo may not support Qt Quick 3D model rendering in all environments.  
Use this pipeline to pre-render `.glb/.gltf` assets into transparent PNG turntables:

```bash
./tools/render_turntables.sh
```

Output goes to `assets/renders/<model_name>/` as frame sequences like:

`assets/renders/ice_cream_truck/ice_cream_truck_000.png`

### Optional quality controls

```bash
FRAMES=36 SIZE=768 ./tools/render_turntables.sh
```

Environment variables:

- `FRAMES` number of images around 360° (default `24`)
- `SIZE` output width/height in pixels (default `640`)
- `MODEL_TILT_DEG` static model tilt angle (default `-8`)
- `BLENDER_BIN` explicit Blender binary path (auto-detected if omitted)

### Normalize framing (trim + center + scale)

After rendering, normalize all frame sequences so models are centered and consistently sized in the story card:

```bash
./tools/normalize_turntable_frames.sh
```

### One-click redirect (GitHub Pages optional)

`play.html` already points at the raw `main.qml` for this repo. If you enable **GitHub Pages**, visitors can open `…/play.html` for a one-click redirect to Web Dojo.
