// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DropConvert",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DropConvert", targets: ["DropConvert"])
    ],
    targets: [
        .executableTarget(
            name: "DropConvert",
            path: "Sources/DropConvert"
        ),
        .testTarget(
            name: "DropConvertTests",
            dependencies: ["DropConvert"],
            path: "Tests/DropConvertTests"
        )
    ]
)
