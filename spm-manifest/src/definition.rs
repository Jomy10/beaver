use std::collections::{HashMap, HashSet};

use serde::{de, Deserialize, Deserializer};

/// - see: https://github.com/swiftlang/swift-package-manager/blob/6a2e45f2a625cb9920285f77c638c342b837e382/Sources/PackageModel/Manifest/Manifest.swift#L22
#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Manifest {
    pub name: String,
    #[serde(rename = "cLanguageStandard")]
    pub cstand: Option<String>,
    #[serde(rename = "cxxLanguageStandard")]
    pub cxxstand: Option<String>,
    pub swift_language_versions: Option<Vec<String>>,
    // ignored: dependencies
    pub package_kind: PackageReferenceKind,
    /// The pkg-config name of a system package
    pub pkg_config: Option<String>,
    pub platforms: Vec<PlatformDescription>,
    pub products: Vec<ProductDescription>,
    pub providers: Option<SystemPackageProviderDescription>,
    pub targets: Vec<TargetDescription>,
    pub tools_version: ToolsVersion
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub enum PackageReferenceKind {
    Root(AbsolutePath)
}

pub type AbsolutePath = Vec<String>;

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct PlatformDescription {
    pub platform_name: String,
    pub version: String,
    pub options: Vec<String>
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct ProductDescription {
    pub name: String,
    /// The targets that make up this product
    pub targets: Vec<String>,
    pub r#type: ProductType,
}

#[derive(Deserialize, Debug, Copy, Clone)]
#[serde(rename_all = "camelCase")]
pub enum ProductType {
    #[serde(deserialize_with = "product_type_field_library_deserialize")]
    Library(LibraryType),
    Executable,
    Plugin,
    Snippet,
    Test,
    Macro
}

fn product_type_field_library_deserialize<'de, D: Deserializer<'de>>(de: D) -> Result<LibraryType, D::Error> {
    struct Visitor;

    impl<'de> de::Visitor<'de> for Visitor {
        type Value = LibraryType;

        fn expecting(&self, formatter: &mut std::fmt::Formatter) -> std::fmt::Result {
            formatter.write_str("an array containing the library type as a string")
        }

        fn visit_seq<A>(self, mut seq: A) -> Result<Self::Value, A::Error>
        where A: de::SeqAccess<'de>,
        {
            let Some(elem) = seq.next_element::<String>()? else {
                return Err(de::Error::invalid_length(0, &"1"));
            };

            return Ok(LibraryType::try_from(elem.as_str()).map_err(|msg| de::Error::custom(msg))?);
        }
    }

    de.deserialize_seq(Visitor)
}

#[derive(Deserialize, Debug, Copy, Clone)]
#[serde(rename_all = "camelCase")]
pub enum LibraryType {
    Static,
    Dynamic,
    Automatic
}

impl TryFrom<&str> for LibraryType {
    type Error = String;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "static" => Ok(LibraryType::Static),
            "dynamic" => Ok(LibraryType::Dynamic),
            "automatic" => Ok(LibraryType::Automatic),
            _ => Err(format!("Invalid LibraryType {}", value))
        }
    }
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub enum SystemPackageProviderDescription {
    Brew(Vec<String>),
    Apt(Vec<String>),
    Yum(Vec<String>),
    Nuget(Vec<String>),
    Pkg(Vec<String>),
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct TargetDescription {
    pub name: String,
    pub package_access: bool,
    pub path: Option<String>,
    /// url of the binary target artifact
    pub url: Option<String>,
    pub sources: Option<Vec<String>>,
    pub resources: Vec<Resource>,
    pub exclude: Vec<String>,
    pub dependencies: Vec<Dependency>,
    pub public_headers_path: Option<String>,
    pub r#type: TargetKind,
    pub pkg_config: Option<String>,
    pub providers: Option<Vec<SystemPackageProviderDescription>>,
    pub plugin_capability: Option<PluginCapability>,
    /// The target-specific build settings declared in this target
    pub settings: Vec<TargetBuildSettingDescriptionSetting>,
    /// The binary target checksum
    pub checksum: Option<String>,
    pub plugin_usages: Option<Vec<PluginUsage>>,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Resource {
    pub rule: Rule,
    pub path: String,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub enum Rule {
    Process(Localization),
    #[serde(deserialize_with = "empty_rule_deserialize")]
    Copy(()),
    #[serde(deserialize_with = "empty_rule_deserialize")]
    EmbedInCode(()),
}

fn empty_rule_deserialize<'de, D: Deserializer<'de>>(de: D) -> Result<(), D::Error> {
    struct Visitor;

    impl<'de> de::Visitor<'de> for Visitor {
        type Value = ();

        fn expecting(&self, formatter: &mut std::fmt::Formatter) -> std::fmt::Result {
            formatter.write_str("empty struct")
        }

        fn visit_map<A>(self, _map: A) -> Result<Self::Value, A::Error>
        where A: de::MapAccess<'de>, {
            Ok(())
        }
    }

    de.deserialize_map(Visitor)
}

#[derive(Deserialize, Debug, Copy, Clone)]
#[serde(rename_all = "camelCase")]
pub enum Localization {
    Default,
    Base
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub enum Dependency {
    Target {
        name: String,
        condition: Option<PackageConditionDescription>,
    },
    Product {
        name: String,
        package: Option<String>,
        #[serde(rename = "moduleAliases")]
        module_aliases: Option<HashMap<String, String>>,
        condition: Option<PackageConditionDescription>,
    },
    ByName {
        name: String,
        condition: Option<PackageConditionDescription>,
    }
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct PackageConditionDescription {
    pub platform_names: Vec<String>,
    pub config: Option<String>,
    pub traits: Option<HashSet<String>>,
}

#[derive(Deserialize, Debug, Copy, Clone)]
#[serde(rename_all = "camelCase")]
pub enum TargetKind {
    Regular,
    Executable,
    Test,
    System,
    Binary,
    Plugin,
    Macro
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub enum PluginCapability {
    BuildTool,
    Command {
        intent: PluginCommandIntent,
        permissions: Vec<PluginPermission>,
    }
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub enum PluginCommandIntent {
    DocumentationGeneration,
    SourceCodeFormatting,
    Custom { verb: String, description: String },
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub enum PluginPermission {
    AllowNetworkConnections {
        scope: PluginNetworkPermissionScope,
        reason: String
    },
    WriteToPackageDirectory{ reason: String },
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub enum PluginNetworkPermissionScope {
    None,
    Local { ports: Vec<i32> },
    All { ports: Vec<i32> },
    Docker,
    UnixDomainSocket,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct TargetBuildSettingDescriptionSetting {
    pub tool: TargetBuildSettingDescriptionTool,
    pub kind: TargetBuildSettingDescriptionKind,
    pub condition: Option<PackageConditionDescription>
}

#[derive(Deserialize, Debug, Clone, Copy)]
#[serde(rename_all = "camelCase")]
pub enum TargetBuildSettingDescriptionTool {
    C,
    CXX,
    Swift,
    Linker,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub enum TargetBuildSettingDescriptionKind {
    HeaderSearchPath(String),
    Define(String),
    LinkedLibrary(String),
    LinkedFramework(String),
    InteroperabilityMode(InteropModeWrapper),
    EnableUpcomingFeature(String),
    EnableExperimentalFeature(String),
    StrictMemorySafety,
    UnsafeFlags(Vec<String>),
    SwiftLanguageMode(String),
}

#[derive(Deserialize, Debug)]
pub struct InteropModeWrapper(HashMap<String, InteroperabilityMode>);

impl InteropModeWrapper {
    fn mode(&self) -> InteroperabilityMode {
        *self.0.get("_0").unwrap()
    }
}

impl PartialEq for InteropModeWrapper {
    fn eq(&self, other: &Self) -> bool {
        self.mode() == other.mode()
    }
}

#[derive(Deserialize, Debug, Clone, Copy, PartialEq)]
pub enum InteroperabilityMode {
    C,
    #[serde(rename = "Cxx")]
    CXX
}

#[derive(Deserialize, Debug)]
#[serde(rename = "swiftLanguageMode")]
pub enum PluginUsage {
    Plugin { name: String, package: Option<String> }
}

#[derive(Deserialize, Debug)]
pub struct ToolsVersion {
    #[serde(rename = "_version")]
    pub version: String
}
