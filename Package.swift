// swift-tools-version:5.9
// Open this file in Xcode to edit and run the app.
// To build the installable app, run: bash build.command

import PackageDescription

let package = Package(
    name: "CleanMacDev",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CleanMacDev",
            path: "Sources/CleanMacDev"
        ),
    ]
)
