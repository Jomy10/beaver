mod definition;
pub use definition::*;

pub type Error = serde_json::Error;

impl Manifest {
    pub fn parse(str: &str) -> Result<Manifest, Error> {
        serde_json::from_str(str)
    }
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::process::Command;

    use crate::Manifest;

    #[test]
    fn test_manifest_parser() {
        let tmpdir = tempdir::TempDir::new("be.jonaseveraert.beaver.tests.spm-definition").unwrap();
        let manifest_path = tmpdir.path().join("Package.swift");
        let manifest = r#"
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
                .library(
                  name: "Beaver",
                  targets: ["Beaver"]),
              ],
              dependencies: [
                .package(url: "https://github.com/ddddxxx/Semver", from: "0.2.0"),
                .package(url: "https://github.com/davbeck/swift-glob.git", from: "0.1.0"),
                .package(url: "https://github.com/mtynior/ColorizeSwift.git", from: "1.5.0"),
                .package(url: "https://github.com/apple/swift-atomics", from: "1.2.0"),
                //.package(url: "https://github.com/apple/swift-collections.git", from: "1.1.4"),
                //.package(url: "https://github.com/FabrizioBrancati/Queuer.git", from: "3.0.0"),
                //.package(url: "https://github.com/SwiftyLab/AsyncObjects.git", from: "2.1.0"),
                .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.3"),
                //.package(url: "https://github.com/Jomy10/TaskProgress", branch: "master"),
                .package(url: "https://github.com/Jomy10/SQLite.swift.git", branch: "master"),
                //.package(path: "../RubyGateway"),
                .package(url: "https://github.com/Jomy10/RubyGateway.git", branch: "main"),
                .package(url: "https://github.com/apple/swift-syntax", from: "600.0.0"),
                .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from: "1.8.4"),
                //.package(path: "../simple-graph-swift"),
              ],
              targets: [
                //=== CLI ===//
                .executableTarget(
                  name: "BeaverCLI",
                  dependencies: [
                    "Beaver",
                    "BeaverRuby",
                    //"UtilMacros",
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

                //=== Ruby ===//
                .target(
                  name: "BeaverRuby",
                  dependencies: [
                    "Beaver",
                    "Utils",
                    //"WorkQueue",
                    //.product(name: "CRuby", package: "CRuby"),
                    //.product(name: "AsyncObjects", package: "AsyncObjects"),
                    .product(name: "RubyGateway", package: "RubyGateway"),
                    .product(name: "Atomics", package: "swift-atomics"),
                    //.product(name: "Queuer", package: "Queuer"),
                    .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                  ],
                  resources: [.embedInCode("lib")]
                ),

                //=== Beaver Library ===//
                .target(
                  name: "Beaver",
                  dependencies: [
                    "csqlite3_glue",
                    "UtilMacros",
                    "CacheMacros",
                    "Platform",
                    "timespec",
                    "Utils",
                    .product(name: "Glob", package: "swift-glob"),
                    .product(name: "Semver", package: "Semver"),
                    .product(name: "SQLite", package: "SQLite.swift"),
                    .product(name: "CryptoSwift", package: "CryptoSwift"),
                    .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                  ]
                ),
                //=== Utils ===//
                .macro(
                  name: "CacheMacros",
                  dependencies: [
                    .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                    .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                    .product(name: "SwiftSyntax", package: "swift-syntax"),
                    .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                    .product(name: "SwiftParser", package: "swift-syntax"),
                  ]
                ),
                .target(
                  name: "csqlite3_glue",
                  dependencies: [
                    .product(name: "CSQLite", package: "SQLite.swift")
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
                    //"ProgressIndicators",
                    //"UtilMacros",
                    .product(name: "ColorizeSwift", package: "ColorizeSwift"),
                    .product(name: "Atomics", package: "swift-atomics"),
                  ]
                ),

                //=== Tests ===//
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
        "#;

        fs::write(&manifest_path, manifest).unwrap();

        assert!(tmpdir.path().exists());
        assert!(manifest_path.exists());

        let output = Command::new("swift")
            .args(&["package", "dump-package"])
            .current_dir(tmpdir.path())
            .output()
            .unwrap();
        assert_eq!(output.status.code(), Some(0));
        let json = String::from_utf8(output.stdout).unwrap();

        // println!("{}", &json);

        _ = Manifest::parse(&json).unwrap();
    }
}
