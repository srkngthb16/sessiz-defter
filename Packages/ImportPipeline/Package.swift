// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ImportPipeline",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ImportPipeline", targets: ["ImportPipeline"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Domain")
    ],
    targets: [
        .target(name: "ImportPipeline", dependencies: ["Core", "Domain"]),
        .testTarget(
            name: "ImportPipelineTests",
            dependencies: ["ImportPipeline"],
            resources: [.copy("Fixtures")]
        )
    ]
)
