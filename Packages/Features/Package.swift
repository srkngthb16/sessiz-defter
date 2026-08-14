// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Features",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Features", targets: ["Features"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Domain"),
        .package(path: "../DesignSystem")
    ],
    targets: [
        // Ekranlar App hedefinde değil ayrı pakette: App hedefi test edilemiyor,
        // ekran snapshot'ları ise zorunlu.
        .target(name: "Features", dependencies: ["Core", "Domain", "DesignSystem"]),
        .testTarget(
            name: "FeaturesTests",
            dependencies: [
                "Features",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "SnapshotSupport", package: "DesignSystem")
            ],
            exclude: ["__Snapshots__"])
    ]
)
