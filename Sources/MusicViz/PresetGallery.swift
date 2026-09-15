import SwiftUI

struct PresetGallery: View {
    @ObservedObject var controller: ProjectMController
    let dismiss: () -> Void
    @State private var query = ""
    @State private var favoritesOnly = false

    private var visiblePresets: [PresetDescriptor] {
        controller.presets.filter { preset in
            (!favoritesOnly || controller.favorites.contains(preset.id)) &&
            (query.isEmpty || preset.name.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("MilkDrop Library").font(.title2.bold())
                    Text("\(controller.presets.count) bundled presets").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done", action: dismiss)
            }

            HStack {
                TextField("Search presets", text: $query)
                    .textFieldStyle(.roundedBorder)
                Toggle("Favorites", isOn: $favoritesOnly)
                    .toggleStyle(.button)
                Button(controller.isGeneratingThumbnails ? "Generating \(controller.thumbnailProgress)/\(controller.presets.count)" : "Generate previews") {
                    controller.generateThumbnails()
                }
                .disabled(controller.isGeneratingThumbnails)
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 12)], spacing: 12) {
                    ForEach(visiblePresets) { preset in
                        VStack(alignment: .leading, spacing: 7) {
                                PresetThumbnail(preset: preset, imageURL: controller.thumbnailURLs[preset.id])
                                    .frame(height: 90)
                                HStack(alignment: .top, spacing: 4) {
                                    Text(preset.name)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(2)
                                    Spacer(minLength: 0)
                                    Button {
                                        controller.toggleFavorite(preset.id)
                                    } label: {
                                        Image(systemName: controller.favorites.contains(preset.id) ? "star.fill" : "star")
                                            .foregroundStyle(controller.favorites.contains(preset.id) ? .yellow : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                        }
                        .padding(8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture {
                            controller.select(preset)
                            dismiss()
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 520)
    }
}

private struct PresetThumbnail: View {
    let preset: PresetDescriptor
    let imageURL: URL?

    var body: some View {
        if let imageURL, let image = NSImage(contentsOf: imageURL) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        } else {
        let color = Color(red: preset.red, green: preset.green, blue: preset.blue)
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(roundedRect: rect, cornerRadius: 7), with: .linearGradient(
                Gradient(colors: [.black, color.opacity(0.95), color.opacity(0.18), .black]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: size.height)
            ))
            for index in 0..<5 {
                let fraction = CGFloat(index + 1) / 6
                let radius = min(size.width, size.height) * fraction * 0.55
                context.stroke(Path(ellipseIn: CGRect(x: size.width * (0.5 - fraction / 2), y: size.height * (0.5 - fraction / 2), width: radius * 2, height: radius * 1.1)), with: .color(.white.opacity(0.14)), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
        }
    }
}
