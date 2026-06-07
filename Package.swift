// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DjayPlaylistBridge",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DjayPlaylistBridgeCore", targets: ["DjayPlaylistBridgeCore"]),
    ],
    targets: [
        .target(
            name: "DjayPlaylistBridgeCore",
            path: "DjayPlaylistBridge",
            exclude: [
                "AppModel.swift",
                "ContentView.swift",
                "DjayPlaylistBridgeApp.swift",
                "Assets.xcassets",
                "Info.plist",
                "DjayPlaylistBridge.entitlements",
                "Views",
                "Services/MusicPlaylistBuilder.swift",
                "Services/CatalogMatcher.swift",
            ],
            sources: [
                "Models",
                "Services/DurationParser.swift",
                "Services/DjayCsvParser.swift",
                "Services/TrackResolver.swift",
                "Services/M3u8Writer.swift",
                "Services/PlaylistConverter.swift",
            ]
        ),
        .testTarget(
            name: "DjayPlaylistBridgeCoreTests",
            dependencies: ["DjayPlaylistBridgeCore"],
            path: "DjayPlaylistBridgeTests",
            exclude: ["fixtures"],
            resources: [.copy("fixtures")]
        ),
    ]
)
