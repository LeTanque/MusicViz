// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MusicViz",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MusicViz", targets: ["MusicViz"])
    ],
    targets: [
        .target(
            name: "CProjectM",
            path: "Sources/CProjectM",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("../../.projectm-install/include")
            ]
        ),
        .executableTarget(
            name: "MusicViz",
            dependencies: ["CProjectM"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("OpenGL"),
                .linkedFramework("SwiftUI")
                , .unsafeFlags([
                    "-L", ".projectm-install/lib",
                    "-lprojectM-4",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        )
    ]
)
