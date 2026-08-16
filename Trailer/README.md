# Shelf trailer scene

Blender 5, 10 seconds at 24 fps. Open `ShelfTrailer.blend`.

Walnut desk, plaster walls, a MacBook that opens and closes, and a floating Shelf panel painted at the real 520×620 liquid-glass layout (Inbox / search / Finder tabs / 138pt cards / ⌥ Space).

The camera starts on the closed laptop, the lid opens, Shelf summons, then the camera turns around the pair. Depth of field is off. UI frames swap Inbox → Work → Personal → hover.

## Timeline

| Frames | What you see |
| --- | --- |
| 1–80 | Inbox UI. Coastal photo, HIG link, Q3 brief, Swift snippet, alpine lake, System Blue. First props arrive. |
| 82–148 | Work UI. SOW PDF, Linear ticket, DuplicateDetector.swift, studio headphones, invoice, Graphite. Code / cans / chips fly in. |
| 148–202 | Personal UI. Figs, pencil notes, quiet chair, packing list, Sunset, reservations. |
| 202–240 | Hover state on Coastal Highway. Hero push-in. |

Regenerate UI frames with `python3 Trailer/make_textures.py` (writes `Trailer/textures/`). Images are packed into the `.blend`.

## Render

Cycles GPU, 1920×1080, 128 samples, AgX Medium High Contrast.

```bash
ffmpeg -framerate 24 -i Trailer/renders/shelf_trailer_%04d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 16 Trailer/renders/shelf_trailer.mp4
```
