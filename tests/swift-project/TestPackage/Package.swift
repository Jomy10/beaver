// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "TestPackage",
    products: [
        .library(
            name: "TestPackage",
            type: .static,
            targets: ["TestPackage"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TestPackage",
            dependencies: []),
    ]
)
