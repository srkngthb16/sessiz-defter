// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Persistence", targets: ["Persistence"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Domain")
    ],
    targets: [
        // SwiftData yalnızca bu hedefte. Domain buraya bağımlı DEĞİL; bağımlılık
        // yönü Persistence → Domain, yani protokoller Domain'de, gerçekleme burada.
        .target(name: "Persistence", dependencies: ["Core", "Domain"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"])
    ]
)
