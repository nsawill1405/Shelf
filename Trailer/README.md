# Shelf trailer scene

Blender 5 scene for a 10-second product trailer. Open `ShelfTrailer.blend`.

**Line:** files, links, and snippets fall through a dark studio and land on a floating glass Shelf.

## Shot list (24 fps, frames 1–240)

| Frames | Beat |
| --- | --- |
| 1–70 | Wide: items drop in from above around the glass panel |
| 70–150 | Push in, then orbit to a three-quarter of the Inbox UI |
| 150–240 | Hero close on the liquid-glass panel |

Camera is on `CamRig` (Z rotation) with `Camera` tracking `CamTarget`. Lens eases 45 → 62 mm. DOF is on, f/2.0, focused on the target.

## How to render

Cycles, GPU, 1920×1080, 128 samples, AgX Medium High Contrast.

Output is set to `Trailer/renders/shelf_trailer_####.png`. In Blender: Render → Render Animation, then encode with ffmpeg:

```bash
ffmpeg -framerate 24 -i Trailer/renders/shelf_trailer_%04d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 16 Trailer/renders/shelf_trailer.mp4
```

Collections: `ENV` studio, `SHELF` panel + icon, `ITEMS` cards and falling pieces, `LIGHTS`, `CAMERA`, `FX` volume.
