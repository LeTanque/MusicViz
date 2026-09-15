# MusicViz

A native macOS visualizer for whatever is playing on the Mac.

This first working slice uses Core Audio process taps to read system audio in real time,
then drives a lightweight built-in spectrum field. It is deliberately separated into:

- `SystemAudioCapture`: capture and normalization of raw PCM samples.
- `AudioAnalyzer`: a renderer-neutral audio feature snapshot.
- `VisualizerView`: the initial native visualization surface.

MilkDrop is the next renderer integration point: `AudioAnalyzer` will feed projectM,
while `PresetLibrary` will own preset discovery, favorites, and import.

## Build and run

```zsh
./Scripts/build-app.sh
open build/MusicViz.app
```

On first launch, start audio playback and press **Start system audio**. macOS will ask
for System Audio Recording permission. MusicViz only analyses buffers in memory; it does
not write or retain audio.
