// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ShowdownKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ShowdownKit", targets: ["ShowdownKit"]),
    ],
    targets: [
        .target(name: "ShowdownKit"),
        .testTarget(
            name: "ShowdownKitTests",
            dependencies: ["ShowdownKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
