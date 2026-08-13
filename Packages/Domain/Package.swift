// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Domain",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Domain", targets: ["Domain"])
    ],
    dependencies: [
        .package(path: "../Core")
    ],
    targets: [
        // Domain saf Swift kalır: SwiftData/SwiftUI bu hedefte import EDİLMEZ.
        // Kuralı ArchitectureTests kaynak taraması ile doğrular.
        .target(name: "Domain", dependencies: ["Core"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain"])
    ]
)
