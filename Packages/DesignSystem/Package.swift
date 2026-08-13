// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "SnapshotSupport", targets: ["SnapshotSupport"])
    ],
    dependencies: [
        .package(path: "../Core")
    ],
    targets: [
        .target(
            name: "DesignSystem",
            dependencies: ["Core"],
            resources: [.copy("Resources/Fonts")]
        ),
        // Snapshot altyapısı üçüncü parti paket kullanmaz; render + PNG karşılaştırma
        // yalnızca UIKit/SwiftUI ile yapılır (kısıt 6).
        .target(name: "SnapshotSupport"),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem", "SnapshotSupport"],
            exclude: ["__Snapshots__"]
        )
    ]
)
