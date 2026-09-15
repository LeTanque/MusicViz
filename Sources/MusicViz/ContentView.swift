import SwiftUI

enum Palette: String, CaseIterable, Identifiable {
    case ion, ultraviolet, ember
    var id: String { rawValue }

    var name: String { rawValue.capitalized }
    var colors: [Color] {
        switch self {
        case .ion: [.cyan, .blue, .indigo]
        case .ultraviolet: [.pink, .purple, .indigo]
        case .ember: [.yellow, .orange, .red]
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: VisualizerModel
    @State private var isFullscreen = false

    var body: some View {
        ZStack {
            VisualizerView(analyzer: model.analyzer, palette: model.palette, gain: model.gain, smoothing: model.smoothing)
                .ignoresSafeArea()

            if !isFullscreen {
                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("MusicViz")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("Native audio-reactive visualizer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(model.status)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(model.isCapturing ? .mint : .secondary)
                    }
                    .padding(20)
                    .background(.black.opacity(0.44))

                    Spacer()

                    controls
                        .padding(20)
                        .background(.black.opacity(0.54))
                }
            }
        }
        .background(.black)
        .onChange(of: model.gain) { _, _ in model.saveSettings() }
        .onChange(of: model.smoothing) { _, _ in model.saveSettings() }
        .onChange(of: model.palette) { _, _ in model.saveSettings() }
    }

    private var controls: some View {
        HStack(spacing: 20) {
            Button {
                model.toggleCapture()
            } label: {
                Label(model.isCapturing ? "Stop" : "Start system audio", systemImage: model.isCapturing ? "stop.fill" : "play.fill")
                    .frame(minWidth: 150)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isCapturing ? .red : .blue)

            Divider().frame(height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Gain").font(.caption)
                Slider(value: $model.gain, in: 0.25...3)
                    .frame(width: 130)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Smoothing").font(.caption)
                Slider(value: $model.smoothing, in: 0...0.95)
                    .frame(width: 130)
            }
            Picker("Palette", selection: $model.palette) {
                ForEach(Palette.allCases) { palette in
                    Text(palette.name).tag(palette)
                }
            }
            .frame(width: 125)

            Spacer()

            Button {
                if let window = NSApp.keyWindow {
                    window.toggleFullScreen(nil)
                    isFullscreen.toggle()
                }
            } label: {
                Label(isFullscreen ? "Show controls" : "Fullscreen", systemImage: isFullscreen ? "rectangle.compress.vertical" : "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.bordered)
        }
        .foregroundStyle(.white)
    }
}

struct VisualizerView: View {
    let analyzer: AudioAnalyzer
    let palette: Palette
    let gain: Double
    let smoothing: Double
    @State private var frame = AudioFrame()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { _ in
            Canvas { context, size in
                let colors = palette.colors
                let gradient = Gradient(colors: colors + [colors.last!.opacity(0)])
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxHeight = size.height * 0.42
                let spacing = size.width / CGFloat(max(1, frame.bands.count))

                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
                for (index, rawValue) in frame.bands.enumerated() {
                    let value = CGFloat(min(1, Double(rawValue) * gain))
                    let height = max(2, value * maxHeight)
                    let x = CGFloat(index) * spacing + spacing * 0.15
                    let bar = CGRect(x: x, y: center.y - height, width: spacing * 0.7, height: height * 2)
                    context.fill(Path(roundedRect: bar, cornerRadius: spacing * 0.3), with: .linearGradient(gradient, startPoint: CGPoint(x: x, y: center.y - height), endPoint: CGPoint(x: x, y: center.y + height)))
                }

                var wave = Path()
                for (index, sample) in frame.waveform.enumerated() {
                    let x = CGFloat(index) / CGFloat(max(1, frame.waveform.count - 1)) * size.width
                    let y = center.y + CGFloat(sample) * size.height * 0.22 * CGFloat(gain)
                    index == 0 ? wave.move(to: CGPoint(x: x, y: y)) : wave.addLine(to: CGPoint(x: x, y: y))
                }
                context.stroke(wave, with: .color(colors[0].opacity(0.55 + Double(frame.beat) * 0.45)), lineWidth: 1.5 + Double(frame.beat) * 3)
            }
            .onChange(of: Date().timeIntervalSinceReferenceDate) { _, _ in
                frame = analyzer.snapshot()
            }
        }
    }
}
