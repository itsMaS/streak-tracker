# Donkey spritesheet

The zoo's donkey is frame-animated. The app currently ships hand-drawn SVG
recreations of the original raster spritesheet (see the `dk-*` symbols in the
`ART` module in `app.html`) — the original PNG wasn't available on this
machine when the sprites were built, only its picture in chat.

## Frame layout (5 x 3)

| | | | | |
|---|---|---|---|---|
| walk1 | walk2 | walk3 | happy1 | happy2 |
| starve1 | starve2 | starve3 | lie | sleep |
| face-happy | face-sick | face-sad | face-cry | face-angry |

Named animations (see `frames.json`): `walk`, `starve`, `happy` (rolling on
its back laughing), `doze` (lie/sleep with Zzz). The five `face-*` frames are
standalone emotes.

## Using the original PNG

Drop the original sheet here as `source/donkey-sheet.png` (any size; it's
sliced by even grid) and run from the repo root:

    python3 tools/slice_spritesheet.py assets/donkey/source/donkey-sheet.png

That writes `frames/<name>.png` (background removed, trimmed) plus
`frames/atlas.json` with per-frame boxes and the animation table — ready for
`<img>`, CSS `background-image`, canvas `drawImage`, or any engine's atlas
import. The in-app frame ids are `dk-<name>`, so a later swap from SVG to the
raster frames is a rename-free change.
