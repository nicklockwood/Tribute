// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Tribute",
    products: [
        .executable(name: "tribute", targets: ["Tribute"]),
    ],
    targets: [
        .target(name: "Tribute", path: "Sources"),
    ]
)
