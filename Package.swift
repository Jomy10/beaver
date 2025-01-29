// swift-tools-version: 6.0

import PackageDescription
import CompilerPluginSupport

let package = Package(
  name: "Beaver",
  // TODO: to .v10_15 and provide backwards compatibility
  platforms: [.macOS(.v15)],
  products: [
    .executable(
      name: "beaver",
      targets: ["BeaverCLI"]),
    //.executable(
    //  name: "Test",
    //  targets: ["Test"]),
    .library(
      name: "Beaver",
      targets: ["Beaver"]),
  ],
  dependencies: [
    .package(url: "https://github.com/ddddxxx/Semver", from: "0.2.0"),
    .package(url: "https://github.com/davbeck/swift-glob.git", from: "0.1.0"),
    .package(url: "https://github.com/mtynior/ColorizeSwift.git", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-atomics", from: "1.2.0"),
    .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.4"),
    //.package(url: "https://github.com/groue/Semaphore", from: "0.1.0"),
    .package(url: "https://github.com/FabrizioBrancati/Queuer.git", from: "3.0.0"),
    .package(url: "https://github.com/SwiftyLab/AsyncObjects.git", from: "2.1.0"),
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.3"),
    //.package(url: "https://github.com/Jomy10/TaskProgress", branch: "master"),
    .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.3"),
    //.package(url: "https://github.com/johnfairh/RubyGateway", from: "6.0.0"),
    //.package(path: "../RubyGateway"),
    .package(url: "https://github.com/Jomy10/RubyGateway", branch: "main"),
    //.package(url: "https://github.com/johnfairh/CRuby", from: "2.1.0"),
    .package(url: "https://github.com/apple/swift-syntax", from: "600.0.0"),
    .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from: "1.8.4"),
  ],
  targets: [
    .executableTarget(
      name: "BeaverCLI",
      dependencies: [
        "Beaver",
        "BeaverRuby",
        "UtilMacros",
        "Utils",
        "CLIPackage",
      ],
      path: "Sources/BeaverCLI/BeaverCLI"
    ),
    .target(
      name: "CLIPackage",
      dependencies: ["CLIMacros"],
      path: "Sources/BeaverCLI/CLIPackage"
    ),
    .macro(
      name: "CLIMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
      ],
      path: "Sources/BeaverCLI/CLIMacros"
    ),
    .target(
      name: "BeaverRuby",
      dependencies: [
        "Beaver",
        "Utils",
        //.product(name: "CRuby", package: "CRuby"),
        .product(name: "AsyncObjects", package: "AsyncObjects"),
        .product(name: "RubyGateway", package: "RubyGateway"),
        .product(name: "Atomics", package: "swift-atomics"),
        .product(name: "Queuer", package: "Queuer"),
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
      ],
      resources: [.copy("lib")]
    ),
    .target(
      name: "Beaver",
      dependencies: [
        "Platform",
        "timespec",
        "Utils",
        .product(name: "Semver", package: "Semver"),
        .product(name: "Glob", package: "swift-glob"),
        //.product(name: "ColorizeSwift", package: "ColorizeSwift"),
        .product(name: "Atomics", package: "swift-atomics"),
        //.product(name: "Tree", package: "tree"),
        .product(name: "Collections", package: "swift-collections"),
        //.product(name: "Semaphore", package: "Semaphore"),
        .product(name: "SQLite", package: "SQLite.swift"),
        .product(name: "CryptoSwift", package: "CryptoSwift"),
        //.product(name: "TaskProgress", package: "TaskProgress"),
      ]
    ),
    .macro(
      name: "UtilMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
      ]
    ),
    .target(
      name: "Utils",
      dependencies: [
        "Platform",
        "ProgressIndicators",
        "UtilMacros",
        .product(name: "ColorizeSwift", package: "ColorizeSwift"),
        .product(name: "Atomics", package: "swift-atomics"),
      ]
    ),
    // Platform-specific implementations in C
    .target(
      name: "CPlatform",
      path: "Sources/Platform/CPlatform"
    ),
    .target(
      name: "Platform",
      dependencies: [
        "CPlatform"
      ],
      path: "Sources/Platform/Platform"
    ),
    .target(
      name: "timespec",
      path: "deps/timespec",
      publicHeadersPath: "."
    ),
    .systemLibrary(
      name: "ProgressIndicatorsFFI",
      path: "Sources/ProgressIndicators/ffi"
    ),
    .target(
      name: "ProgressIndicators",
      dependencies: ["ProgressIndicatorsFFI"],
      path: "Sources/ProgressIndicators/binding"
    ),
    //.executableTarget(
    //  name: "Test",
    //  dependencies: [
    //    "Beaver",
    //    .product(name: "Tree", package: "tree"),
    //    .product(name: "Semaphore", package: "Semaphore"),
    //    "ProgressIndicators",
    //    "ProgressIndicatorsFFI",
    //    "BeaverRuby",
    //  ]
    //),
    .testTarget(
      name: "BeaverTests",
      dependencies: [
        "Beaver",
        "Utils",
        .product(name: "ColorizeSwift", package: "ColorizeSwift")
      ]
    ),
    .testTarget(
      name: "UtilTests",
      dependencies: [
        "Utils"
      ]
    )
  ]
)
