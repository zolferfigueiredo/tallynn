// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Tallynn",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "Tallynn", swiftSettings: [.defaultIsolation(MainActor.self)]),
        .testTarget(name: "TallynnTests", dependencies: ["Tallynn"]),
    ]
)
