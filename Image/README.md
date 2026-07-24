# Invert GIF Maker

A lightweight, browser-based tool that takes any image and generates an animated GIF that flickers between the original and its color-inverted version — no server, no upload, no dependencies beyond a single JS library.

🔗 **Live:** [https://notnahid.github.io/use/Image/making%20the%20gif.html](https://notnahid.github.io/use/Image/making%20the%20gif.html)
[https://notnahid.github.io/use/Image/making%20the%20gif.html](https://notnahid.github.io/use/Image/both.html)

---

## What it does

1. You upload a local image (PNG, JPG, WebP, etc.)
2. The tool instantly generates the color-inverted version in the browser
3. A live preview shows the flicker effect before you commit
4. You adjust the delay between frames using a slider
5. Hit **Generate & Download GIF** — a 2-frame animated GIF downloads automatically

---

## Features

- Works entirely in the browser — nothing is uploaded anywhere
- Live preview updates in real time as you move the slider
- Adjustable frame delay from 100 ms to 2000 ms
- Displays image dimensions after upload
- Progress bar during GIF encoding
- Auto-downloads the finished GIF and cleans up memory
- Button re-enables after each export so you can regenerate at a different speed

---

## How to use

1. Open the [live page](https://notnahid.github.io/use/Image/making%20the%20gif.html)
2. Click **Choose File** and pick an image from your device
3. Watch the live preview — original and inverted frames alternating
4. Drag the **Delay Between Frames** slider to control speed (lower = faster flicker)
5. Click **Generate & Download GIF**
6. The GIF encodes, then downloads automatically as `flashing.gif`

---

## Technical details

| Detail | Value |
|---|---|
| Output format | Animated GIF (2 frames, infinite loop) |
| GIF library | [gif.js](https://github.com/jnordberg/gif.js) v0.2.0 via cdnjs |
| Inversion method | Per-pixel `255 - value` on R, G, B channels (alpha preserved) |
| Rendering | HTML5 Canvas API |
| Workers | 2 Web Workers for GIF encoding |
| GIF quality setting | 10 (gif.js scale: 1 = best, 20 = fastest) |
| Frame delay range | 100 ms – 2000 ms (step: 50 ms) |
| Dependencies | gif.js (CDN) — no frameworks, no build step |

---

## Files

```
index.html   — the entire tool (single self-contained file)
```

gif.js encodes in Web Workers. If you host this yourself, make sure `gif.worker.js` is served from the same directory as `gif.js`, or the encoding step will silently fail.

---

## Browser support

Any modern browser with support for:
- HTML5 Canvas (`getContext("2d")`)
- Web Workers
- `URL.createObjectURL`

Tested in Chrome, Firefox, and Edge.

---

## Local setup

No build step needed. Just serve the file over HTTP (not `file://` — Web Workers require a server origin):

```bash
# Python 3
python -m http.server 8080

# Node.js (npx)
npx serve .
```

Then open `http://localhost:8080`.

---

## License

Do whatever you want with it.
