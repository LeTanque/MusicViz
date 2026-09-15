# MusicViz

A native macOS visualizer for whatever is playing on the Mac.

MusicViz uses Core Audio process taps to read system audio in real time, then passes it to
the genuine MilkDrop-compatible `libprojectM` renderer. The project includes pinned source
submodules for projectM and the official original MilkDrop preset/texture packs.

The app is deliberately separated into:

- `SystemAudioCapture`: capture and normalization of raw PCM samples.
- `AudioAnalyzer`: a renderer-neutral audio feature snapshot for native effects and UI.
- `AudioBus`: bounded in-memory PCM handoff to the OpenGL render thread.
- `ProjectMOpenGLView`: the MilkDrop renderer, driven directly from system PCM.

The next product layer is the preset browser, favorites, and user `.milk` import.

## Build and run

```zsh
./Scripts/build-app.sh
open build/MusicViz.app
```

On first launch, start audio playback and press **Start system audio**. macOS will ask
for System Audio Recording permission. MusicViz only analyses buffers in memory; it does
not write or retain audio.

## Open-source notices

`libprojectM` is licensed under LGPL-2.1-or-later and is dynamically linked into the
app bundle. MilkDrop preset and texture assets retain their upstream attribution; see their
respective submodule repositories for source and licensing details.
