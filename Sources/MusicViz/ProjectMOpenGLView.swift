import AppKit
import CProjectM
import OpenGL
import SwiftUI

final class ProjectMOpenGLView: NSOpenGLView {
    private let renderInterval: TimeInterval = 1.0 / 30.0
    private let audioBus: AudioBus
    private let controller: ProjectMController
    private var projectM: projectm_handle?
    private var displayTimer: Timer?
    private var presetURLs: [URL] = []
    private var presetIndex = 0
    private var lastRender = Date()
    private var thumbnailQueue: [URL] = []
    private var thumbnailCursor = 0
    private var thumbnailReturnIndex = 0

    init?(audioBus: AudioBus, controller: ProjectMController) {
        self.audioBus = audioBus
        self.controller = controller
        let attributes: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion4_1Core),
            UInt32(NSOpenGLPFAColorSize), 24,
            UInt32(NSOpenGLPFAAlphaSize), 8,
            UInt32(NSOpenGLPFADoubleBuffer),
            UInt32(NSOpenGLPFAAccelerated),
            0
        ]
        guard let pixelFormat = NSOpenGLPixelFormat(attributes: attributes) else { return nil }
        super.init(frame: .zero, pixelFormat: pixelFormat)
        wantsBestResolutionOpenGLSurface = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareOpenGL() {
        super.prepareOpenGL()
        openGLContext?.makeCurrentContext()
        var swapInterval: GLint = 1
        openGLContext?.setValues(&swapInterval, for: .swapInterval)

        guard let instance = projectm_create() else { return }
        projectM = instance
        projectm_set_mesh_size(instance, 48, 36)
        projectm_set_fps(instance, 30)
        projectm_set_soft_cut_duration(instance, 2.0)
        projectm_set_preset_duration(instance, 45.0)
        projectm_set_hard_cut_enabled(instance, true)
        projectm_set_hard_cut_duration(instance, 12.0)

        configureAssets(instance)
        displayTimer = Timer.scheduledTimer(withTimeInterval: renderInterval, repeats: true) { [weak self] _ in
            self?.drawFrame()
        }
        displayTimer?.tolerance = 0.01
    }

    override func reshape() {
        super.reshape()
        guard let projectM else { return }
        let backing = convertToBacking(bounds)
        projectm_set_window_size(projectM, max(1, Int(backing.width)), max(1, Int(backing.height)))
    }

    private func configureAssets(_ instance: projectm_handle) {
        guard let resources = Bundle.main.resourceURL else { return }
        let presetDirectory = resources.appendingPathComponent("MilkDrop/Presets", isDirectory: true)
        let textureDirectory = resources.appendingPathComponent("MilkDrop/Textures", isDirectory: true)
        presetURLs = (try? FileManager.default.contentsOfDirectory(
            at: presetDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension.lowercased() == "milk" }.sorted { $0.lastPathComponent < $1.lastPathComponent }) ?? []
        controller.setPresets(presetURLs.map(PresetDescriptor.init))
        controller.configureThumbnailRendering(textureDirectory: textureDirectory.path)

        textureDirectory.path.withCString { texturePath in
            var paths: [UnsafePointer<CChar>?] = [texturePath]
            paths.withUnsafeMutableBufferPointer { buffer in
                projectm_set_texture_search_paths(instance, buffer.baseAddress, buffer.count)
            }
        }
        loadPreset(at: presetIndex, smooth: false)
    }

    func nextPreset() {
        guard !presetURLs.isEmpty else { return }
        presetIndex = (presetIndex + 1) % presetURLs.count
        loadPreset(at: presetIndex, smooth: true)
    }

    func previousPreset() {
        guard !presetURLs.isEmpty else { return }
        presetIndex = (presetIndex - 1 + presetURLs.count) % presetURLs.count
        loadPreset(at: presetIndex, smooth: true)
    }

    func selectPreset(id: String) {
        guard let index = presetURLs.firstIndex(where: { $0.path == id }) else { return }
        presetIndex = index
        loadPreset(at: index, smooth: true)
    }

    func shufflePreset() {
        guard presetURLs.count > 1 else { return }
        var next = presetIndex
        while next == presetIndex { next = Int.random(in: presetURLs.indices) }
        presetIndex = next
        loadPreset(at: next, smooth: true)
    }

    func generateThumbnails() {
        guard thumbnailQueue.isEmpty else { return }
        thumbnailQueue = presetURLs.filter { !FileManager.default.fileExists(atPath: controller.thumbnailURL(for: $0.path).path) }
        guard !thumbnailQueue.isEmpty else { return }
        thumbnailCursor = 0
        thumbnailReturnIndex = presetIndex
        controller.setThumbnailGeneration(active: true, progress: presetURLs.count - thumbnailQueue.count)
        renderNextThumbnail()
    }

    private func renderNextThumbnail() {
        guard thumbnailCursor < thumbnailQueue.count, let projectM, let context = openGLContext else {
            if !thumbnailQueue.isEmpty { loadPreset(at: thumbnailReturnIndex, smooth: true) }
            thumbnailQueue = []
            controller.setThumbnailGeneration(active: false, progress: presetURLs.count)
            return
        }
        let preset = thumbnailQueue[thumbnailCursor]
        context.makeCurrentContext()
        preset.path.withCString { projectm_load_preset_file(projectM, $0, false) }
        projectm_set_window_size(projectM, 320, 180)
        projectm_opengl_render_frame(projectM)

        let output = controller.thumbnailURL(for: preset.path)
        var pixels = [UInt8](repeating: 0, count: 320 * 180 * 4)
        pixels.withUnsafeMutableBufferPointer { projectm_read_pixels($0.baseAddress, 320, 180) }
        if let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 320, pixelsHigh: 180, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 320 * 4, bitsPerPixel: 32), let data = image.bitmapData {
            pixels.withUnsafeBufferPointer { data.update(from: $0.baseAddress!, count: pixels.count) }
            try? image.representation(using: .png, properties: [:])?.write(to: output)
            controller.storeThumbnail(id: preset.path, url: output)
        }
        thumbnailCursor += 1
        controller.setThumbnailGeneration(active: true, progress: presetURLs.count - thumbnailQueue.count + thumbnailCursor)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in self?.renderNextThumbnail() }
    }

    private func loadPreset(at index: Int, smooth: Bool) {
        guard let projectM, presetURLs.indices.contains(index) else { return }
        presetURLs[index].path.withCString { projectm_load_preset_file(projectM, $0, smooth) }
        controller.setPreset(id: presetURLs[index].path, name: presetURLs[index].deletingPathExtension().lastPathComponent, position: index + 1, total: presetURLs.count)
    }

    private func drawFrame() {
        guard let projectM, let context = openGLContext else { return }
        context.makeCurrentContext()
        let backing = convertToBacking(bounds)
        guard backing.width > 0, backing.height > 0 else { return }

        let now = Date()
        let elapsed = max(0.001, now.timeIntervalSince(lastRender))
        lastRender = now
        projectm_set_fps(projectM, Int32((1.0 / elapsed).rounded()))
        projectm_set_window_size(projectM, Int(backing.width), Int(backing.height))

        let samples = audioBus.snapshot()
        samples.withUnsafeBufferPointer { buffer in
            projectm_pcm_add_float(projectM, buffer.baseAddress, UInt32(buffer.count / 2), PROJECTM_STEREO)
        }
        projectm_opengl_render_frame(projectM)
        context.flushBuffer()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            tearDownRenderer()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    private func tearDownRenderer() {
        displayTimer?.invalidate()
        displayTimer = nil
        openGLContext?.makeCurrentContext()
        if let projectM {
            projectm_destroy(projectM)
            self.projectM = nil
        }
    }
}

struct PresetDescriptor: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let red: Double
    let green: Double
    let blue: Double

    init(url: URL) {
        id = url.path
        name = url.deletingPathExtension().lastPathComponent
        let source = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        red = Self.value("wave_r", in: source, fallback: 0.18)
        green = Self.value("wave_g", in: source, fallback: 0.52)
        blue = Self.value("wave_b", in: source, fallback: 0.94)
    }

    private static func value(_ key: String, in source: String, fallback: Double) -> Double {
        guard let line = source.split(whereSeparator: \.isNewline).first(where: { $0.hasPrefix("\(key)=") }),
              let value = Double(line.dropFirst(key.count + 1)) else { return fallback }
        return min(1, max(0, value))
    }
}

@MainActor
final class ProjectMController: ObservableObject {
    @Published private(set) var presetName = "Loading presets…"
    @Published private(set) var presetPosition = 0
    @Published private(set) var presetTotal = 0
    @Published private(set) var presetID = ""
    @Published private(set) var presets: [PresetDescriptor] = []
    @Published private(set) var favorites: Set<String>
    @Published private(set) var thumbnailURLs: [String: URL] = [:]
    @Published private(set) var thumbnailProgress = 0
    @Published private(set) var isGeneratingThumbnails = false
    weak var renderer: ProjectMOpenGLView?
    private var textureDirectory = ""

    init() {
        favorites = Set(UserDefaults.standard.stringArray(forKey: "favoritePresetIDs") ?? [])
    }

    func previousPreset() { renderer?.previousPreset() }
    func nextPreset() { renderer?.nextPreset() }
    func shufflePreset() { renderer?.shufflePreset() }
    func select(_ preset: PresetDescriptor) { renderer?.selectPreset(id: preset.id) }

    func setPresets(_ presets: [PresetDescriptor]) { self.presets = presets }

    func configureThumbnailRendering(textureDirectory: String) {
        self.textureDirectory = textureDirectory
        for preset in presets {
            let url = thumbnailURL(for: preset.id)
            if FileManager.default.fileExists(atPath: url.path) { thumbnailURLs[preset.id] = url }
        }
    }

    func generateThumbnails() {
        guard !isGeneratingThumbnails, !textureDirectory.isEmpty else { return }
        isGeneratingThumbnails = true
        let remaining = presets.filter { thumbnailURLs[$0.id] == nil }
        thumbnailProgress = presets.count - remaining.count
        renderer?.generateThumbnails()
    }

    func storeThumbnail(id: String, url: URL) { thumbnailURLs[id] = url }
    func setThumbnailGeneration(active: Bool, progress: Int) {
        isGeneratingThumbnails = active
        thumbnailProgress = progress
    }

    func thumbnailURL(for id: String) -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MusicViz/Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in id.utf8 { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
        return directory.appendingPathComponent(String(hash, radix: 16)).appendingPathExtension("png")
    }

    func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        UserDefaults.standard.set(Array(favorites), forKey: "favoritePresetIDs")
    }

    func setPreset(id: String, name: String, position: Int, total: Int) {
        presetID = id
        presetName = name
        presetPosition = position
        presetTotal = total
    }
}

@MainActor
struct ProjectMVisualizer: NSViewRepresentable {
    let audioBus: AudioBus
    let controller: ProjectMController

    func makeNSView(context: Context) -> ProjectMOpenGLView {
        let view = ProjectMOpenGLView(audioBus: audioBus, controller: controller)!
        controller.renderer = view
        return view
    }

    func updateNSView(_ nsView: ProjectMOpenGLView, context: Context) {}
}
