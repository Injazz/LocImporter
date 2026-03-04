// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocImporter",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "LocImporter",
            dependencies: [
                .target(name: "LocImporterLib"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "LocImporterTests",
            dependencies: [
                .target(name: "LocImporterLib"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            resources: [
                .copy("TestCases/")
            ]
        ),
        .target(
            name: "LocImporterLib",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
    ]
)
