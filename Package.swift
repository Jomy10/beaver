// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Beaver",
  // TODO: to .v10_15 and provide backwards compatibility
  platforms: [.macOS(.v15)],
  products: [
    .executable(
      name: "Test",
      targets: ["Test"]
    ),
    .library(
      name: "Beaver",
      targets: ["Beaver"]),
  ],
  dependencies: [
    .package(url: "https://github.com/ddddxxx/Semver", from: "0.2.0"),
    .package(url: "https://github.com/davbeck/swift-glob.git", from: "0.1.0"),
    .package(url: "https://github.com/mtynior/ColorizeSwift.git", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-atomics", from: "1.2.0"),
  ],
  targets: [
    .target(
      name: "Beaver",
      dependencies: [
        "Platform",
        .product(name: "Semver", package: "Semver"),
        .product(name: "Glob", package: "swift-glob"),
        .product(name: "ColorizeSwift", package: "ColorizeSwift"),
        .product(name: "Atomics", package: "swift-atomics")
      ]
    ),
    // Platform-specific implementations in C
    .target(
      name: "CPlatform"
    ),
    .target(
      name: "Platform",
      dependencies: [
        "CPlatform"
      ]
    ),
    .executableTarget(
      name: "Test",
      dependencies: [
        "Beaver"
      ]
    ),
    .testTarget(
      name: "BeaverTests",
      dependencies: ["Beaver"],
      exclude: ["resources"]
    ),
  ]
)
