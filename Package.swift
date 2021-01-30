// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Tribute",
    platforms: [.macOS(.v10_13)],
    products: [
        .executable(name: "tribute", targets: ["Tribute"]),
    ],
    targets: [
        .target(name: "Tribute", path: "Sources"),
    ]
)
