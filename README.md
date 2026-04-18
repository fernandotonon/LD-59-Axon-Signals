# Axon Signals (LD prototype)

Paint myelin on a discrete axon, then watch a short 3D-style playback of the signal racing toward the brain.

## Play in the browser (Web Dojo)

No install needed for players. The game is plain **QML + JavaScript**; [Web Dojo](https://clayground.mistergc.dev/webdojo/) runs Clayground as WebAssembly and loads your sources from a URL.

### After this repo is on GitHub

1. Push the repo (including the `qml/` folder).
2. Open Web Dojo with your **raw** `main.qml` URL (adjust user, repo, and branch):

   **https://clayground.mistergc.dev/webdojo/#clay-src=https://raw.githubusercontent.com/fernandotonon/LD-59-Axon-Signals/main/qml/main.qml**

   (Forks: replace `fernandotonon/LD-59-Axon-Signals` and branch `main` if yours differ.)

3. Click **Run** (or use **auto-reload** if you develop with [`clay-dev-server`](https://clayground.mistergc.dev/docs/getting-started/webdojo/)).

Relative imports (`Playback3D.qml`, `js/signalSim.js`) resolve next to that URL, so no extra steps as long as those files sit beside `main.qml` in the repo.

### Share a short link

With the game open in Web Dojo, use **Share** to pack the session into the URL, or **Standalone** for a minimal player-only view. Best for small snippets; for this multi-file project, the **raw GitHub** link above is usually more reliable.

### Embed with less chrome (optional)

Hash parameters are [documented here](https://clayground.mistergc.dev/docs/getting-started/webdojo/). Example:

`/webdojo/#clay-src=…&clay-hd=0&clay-ed=0&clay-con=0`

## Local desktop build

Requires Qt 5.12+ or Qt 6 (Quick, QuickControls2, QuickLayouts). From the repo root:

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

### One-click redirect (GitHub Pages optional)

`play.html` already points at the raw `main.qml` for this repo. If you enable **GitHub Pages**, visitors can open `…/play.html` for a one-click redirect to Web Dojo.
