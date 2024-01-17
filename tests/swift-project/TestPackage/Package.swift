// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "TestPackage",
    products: [
        .library(
            name: "TestPackage",
            type: .static,
            targets: ["TestPackage"]),
        .executable(
            name: "TestExecutable",
            targets: ["TestExecutable"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TestPackage",
            dependencies: []),
        .executableTarget(name: "TestExecutable")
    ]
)
