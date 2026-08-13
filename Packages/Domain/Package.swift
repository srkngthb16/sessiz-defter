// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Domain",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "DomainTestSupport", targets: ["DomainTestSupport"])
    ],
    dependencies: [
        .package(path: "../Core")
    ],
    targets: [
        // Domain saf Swift kalır: SwiftData/SwiftUI bu hedefte import EDİLMEZ.
        // Kuralı ArchitectureTests kaynak taraması ile doğrular.
        .target(name: "Domain", dependencies: ["Core"]),
        // Bellek içi repository gerçeklemeleri: SwiftData'sız test için.
        .target(name: "DomainTestSupport", dependencies: ["Domain", "Core"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain", "DomainTestSupport"])
    ]
)
