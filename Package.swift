// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MusicViz",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MusicViz", targets: ["MusicViz"])
    ],
    targets: [
        .executableTarget(
            name: "MusicViz",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
