//! Resources
//! - Swift: https://theswiftdev.com/how-to-use-a-swift-library-in-c/

// TODO: look into xrun for macos. (for cross-compilation)
// e.g. xcrun --sdk macosx --find swift

use std::mem::MaybeUninit;
use std::collections::HashMap;
use std::sync::Mutex;

use lazy_static::lazy_static;
use log::warn;
use target_lexicon::Triple;

#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash)]
pub enum Language {
    C,
    CXX,
    OBJC,
    OBJCXX,

    Rust,
    Swift,
}

static CXX_TO_C_LINKER_FLAGS: [&str; 1] = ["-lstdc++"];

lazy_static! {
    static ref OBJCXX_TO_C_LINKER_FLAGS: Vec<&'static str> = {
        let mut v = OBJCXX_LINKER_FLAGS.to_vec();
        v.extend_from_slice(&CXX_TO_C_LINKER_FLAGS);
        v
    };
}

// Swift //

/// Get the SDK and toolchain path for a specific target triple
#[cfg(target_os = "macos")]
mod apple_sdk_paths {
    use std::collections::HashMap;
    use std::ffi::OsString;
    use std::ops::DerefMut;
    use std::os::unix::ffi::OsStringExt;
    use std::path::{Path, PathBuf};
    use std::process::Command;
    use std::sync::Mutex;

    use lazy_static::lazy_static;
    use target_lexicon::Triple;

    use crate::tools;

    lazy_static! {
        static ref APPLE_SDK_PATHS: Mutex<SDKPathsLookup> = Mutex::new(SDKPathsLookup { hm: HashMap::new() });
    }

    pub(super) fn get_sdk_paths() -> impl DerefMut<Target = SDKPathsLookup> {
        APPLE_SDK_PATHS.lock().unwrap()
    }

    pub(super) struct SDKPathsLookup {
        hm: HashMap<Triple, SDKPaths>,
    }

    impl SDKPathsLookup {
        pub(super) fn get<'a>(&'a mut self, triple: &Triple) -> &'a SDKPaths {
            if self.hm.contains_key(triple) {
                self.hm.get(triple).unwrap()
            } else {
                _ = self.hm.insert(triple.clone(), Self::paths_for_triple(triple));
                self.hm.get(triple).unwrap()
            }
        }

        fn paths_for_triple(triple: &Triple) -> SDKPaths {
            let developer_dir = apple_active_developer_directory();
            let developer_dir = Path::new(&developer_dir);
            let toolchain_path = developer_dir.join("Toolchains/XcodeDefault.xctoolchain");
            let (sdk_root, sdk_platform_root, sdk_name) = apple_sdk_root(triple);
            let sdk_root = Path::new(&sdk_root);
            let sdk_platform_root = Path::new(&sdk_platform_root);

            SDKPaths {
                sdk_name,
                sdk_root: sdk_root.to_path_buf(),
                sdk_platform_root: sdk_platform_root.to_path_buf(),
                developer_dir: developer_dir.to_path_buf(),
                toolchain_path,
            }
        }
    }

    pub(super) struct SDKPaths {
        pub(super) sdk_name: &'static str,
        pub(super) sdk_root: PathBuf,
        #[allow(dead_code)]
        pub(super) sdk_platform_root: PathBuf,
        #[allow(dead_code)]
        pub(super) developer_dir: PathBuf,
        pub(super) toolchain_path: PathBuf,
    }

    fn apple_sdk_root(target: &Triple) -> (OsString, OsString, &'static str) {
        let (sdkname, deployment_target) = match target.operating_system {
            target_lexicon::OperatingSystem::MacOSX(deployment_target) |
            target_lexicon::OperatingSystem::Darwin(deployment_target) => {
                ("macosx", deployment_target)
            },
            target_lexicon::OperatingSystem::IOS(deployment_target) => {
                ("ios", deployment_target)
            },
            target_lexicon::OperatingSystem::TvOS(deployment_target) => {
                ("tvos", deployment_target)
            },
            target_lexicon::OperatingSystem::VisionOS(deployment_target) |
            target_lexicon::OperatingSystem::XROS(deployment_target) => {
                ("visionos", deployment_target)
            },
            target_lexicon::OperatingSystem::WatchOS(deployment_target) => {
                ("watchos", deployment_target)
            },
            _ => unreachable!("Checked for Darwin above"),
        };

        let full_sdk_name = if let Some(deployment_target) = deployment_target {
            &format!("{}{}.{}", sdkname, deployment_target.major, deployment_target.minor)
        } else {
            sdkname
        };

        let output = Command::new(tools::xcrun.as_path())
            .args(["--show-sdk-path", "--sdk", full_sdk_name])
            .output()
            .unwrap();

        if !output.status.success() {
            eprint!("{}", String::from_utf8(output.stderr).unwrap());
            print!("{}", String::from_utf8(output.stdout).unwrap());
            panic!("xcrun failed");
        }

        let sdk_path = OsString::from_vec(output.stdout[0..(output.stdout.len() - 1)].to_vec());

        let output = Command::new(tools::xcrun.as_path())
            .args(["--show-sdk-platform-path", "--sdk", full_sdk_name])
            .output()
            .unwrap();

        if !output.status.success() {
            eprint!("{}", String::from_utf8(output.stderr).unwrap());
            print!("{}", String::from_utf8(output.stdout).unwrap());
            panic!("xcrun failed");
        }

        let sdk_platform_path = OsString::from_vec(output.stdout[0..(output.stdout.len() - 1)].to_vec());

        (sdk_path, sdk_platform_path, sdkname)
    }

    fn apple_active_developer_directory() -> OsString {
        let output = Command::new(tools::xcode_select.as_path())
            .args(["--print-path"])
            .output()
            .unwrap();

        if !output.status.success() {
            eprint!("{}", String::from_utf8(output.stderr).unwrap());
            print!("{}", String::from_utf8(output.stdout).unwrap());
            panic!("xcode-select failed");
        }

        // slice string; last character is new line
        OsString::from_vec(output.stdout[0..(output.stdout.len() - 1)].to_vec())
    }
}

#[cfg(target_os = "macos")]
lazy_static! {
    static ref SWIFT_LINKER_FLAGS: Mutex<HashMap<Triple, Box<(Vec<String>, MaybeUninit<Vec<&'static str>>)>>> = Mutex::new(HashMap::new());
}

/// Get the linker flags for a swift target
#[cfg(target_os = "macos")]
fn swift_linker_flags_darwin(triple: &Triple) -> &'static [&'static str] {
    let mut all_linker_flags = SWIFT_LINKER_FLAGS.lock().unwrap();
    if all_linker_flags.contains_key(triple) {
        let linker_flags = all_linker_flags.get(triple).unwrap();
        let linker_flags_ptr = Box::as_ptr(&linker_flags);
        drop(all_linker_flags);
        return unsafe { linker_flags_ptr.as_ref().unwrap().1.assume_init_ref().as_slice() };
    } else {
        let mut sdk_paths_lookup = apple_sdk_paths::get_sdk_paths();
        let sdk_paths = sdk_paths_lookup.get(triple);

        let sdk_name = &sdk_paths.sdk_name;
        let sdk_root = &sdk_paths.sdk_root;
        let toolchain_path = &sdk_paths.toolchain_path;

        let sdk_frameworks_path = sdk_root.join("System/Library/Frameworks");
        let sdk_include_path = sdk_root.join("usr/include");
        let sdk_link_path = sdk_root.join("usr/lib");
        let toolchain_link_base_path_swift = toolchain_path.join("usr/lib/swift");
        let toolchain_link_path_swift = toolchain_link_base_path_swift.join(sdk_name);

        let linker_flags = [
            "--sysroot",
            sdk_root.to_str().expect("should be UTF-8"),
            "-F",
            sdk_frameworks_path.to_str().expect("should be UTF-8"),
            "-I",
            sdk_include_path.to_str().expect("should be UTF-8"),
            "-L",
            sdk_link_path.to_str().expect("should be UTF-8"),
            "-L",
            toolchain_link_path_swift.to_str().expect("should be UTF-8")
        ];

        let mut linker_flags: Box<(Vec<String>, MaybeUninit<Vec<&'static str>>)> = Box::new((linker_flags.into_iter().map(|str| str.to_string()).collect(), MaybeUninit::uninit()));
        let linker_flags_ptr = Box::as_mut_ptr(&mut linker_flags);
        unsafe {
            let v = (*linker_flags_ptr).0.iter().map(|str| str.as_str()).collect();
            (*linker_flags_ptr).1 = MaybeUninit::new(v);
        }
        all_linker_flags.insert(triple.clone(), linker_flags);
        drop(all_linker_flags);
        return unsafe { linker_flags_ptr.as_ref().unwrap().1.assume_init_ref().as_slice() };
    }
}

// OBJC //

#[cfg(target_os = "macos")]
lazy_static! {
    // only for compiling objc itself
    pub static ref OBJC_CFLAGS: &'static [&'static str] = &["-x", "objective-c", "-fobjc-arc", "-fmodules"];
    pub static ref OBJCXX_CFLAGS: &'static [&'static str] = &["-x", "objective-c++", "-fobjc-arc", "-fmodules"];
    pub static ref OBJC_LINKER_FLAGS: &'static [&'static str] = &["-lobjc"];
    pub static ref OBJCXX_LINKER_FLAGS: &'static [&'static str] = &["-lobjc"];
}

#[cfg(not(target_os = "macos"))]
lazy_static! {
    pub static ref OBJC_CFLAGS: &'static [&'static str] = {
        let output = Command::new(gnustep_config)
            .args(["--objc-flags"])
            .output()
            .expect("Failed to get objc-flags from gnustep-config")
            .stdout;
        shlex::bytes::split(output.as_slice())
            .expect(&format!("Couldn't parse arguments `{}`", output))
    };
    pub static ref OBJCXX_CFLAGS: &'static [&'static str] = objc_cflags;
    pub static ref OBJC_LINKER_FLAGS: &'static [&'static str] = {
        let output = Command::new(gnustep_config)
            .args(["--objc-libs", "--base-libs"])
            .output()
            .expect("Failed to get objc-libs from gnustep-config")
            .stdout;
        shlex::bytes::split(output.as_slice())
            .expect(&format!("Couldn't parse arguments `{}`", output))
    };
    pub static ref OBJCXX_LINKER_FLAGS: &'static [&'static str] = OBJC_LINKER_FLAGS;
}

impl Language {
    pub fn parse(s: &str) -> Option<Self> {
        match s.to_uppercase().as_str() {
            "C" => Some(Self::C),
            "CXX" | "C++" | "CPP" => Some(Self::CXX),
            "OBJ-C" | "OBJC" => Some(Self::OBJC),
            "OBJ-CXX" | "OBJ-CPP" | "OBJ-C++" |
            "OBJCXX" | "OBJCPP" | "OBJC++" => Some(Self::OBJCXX),
            _ => None
        }
    }

    pub fn cflags(from: Language, to: Language) -> Option<&'static [&'static str]> {
        use Language::*;

        match (from, to) {
            (OBJC, _) => None,
            (OBJCXX, _) => None,
            // (OBJC, _) => Some(*OBJC_CFLAGS),
            // (OBJCXX, _) => Some(*OBJCXX_CFLAGS),
            (C, _) => None,
            (CXX, _) => None,
            (Rust, _) => None,
            (Swift, _) => None,
        }
    }

    pub fn linker_flags(from: Language, to: Language, target: &Triple) -> Option<&'static [&'static str]> {
        use Language::*;

        match (from, to) {
            (C, _) => None,

            (CXX, C | OBJC) | (OBJCXX, OBJC) => Some(&CXX_TO_C_LINKER_FLAGS),
            (CXX, CXX | OBJCXX) => None,
            (CXX, Rust | Swift) => None,

            (OBJC, CXX | C) => Some(*OBJC_LINKER_FLAGS),
            (OBJCXX, CXX) => Some(*OBJCXX_LINKER_FLAGS),
            (OBJCXX, C) => Some(&OBJCXX_TO_C_LINKER_FLAGS),
            (OBJC, OBJC | OBJCXX) |
            (OBJCXX, OBJCXX) => None,

            (OBJCXX | OBJC, Rust | Swift) => None,

            (Rust, _) => None,

            (Swift, Swift) => None,
            (Swift, _) => {
                if target.operating_system.is_like_darwin() {
                    #[cfg(target_os = "macos")] { Some(swift_linker_flags_darwin(target)) }
                    #[cfg(not(target_os = "macos"))] {
                        error!("Swift linking to {} on non-apple platform is not supported", target);
                        None
                    }
                } else {
                    warn!("Swift linking may not be currently working for {}", target);
                    None
                }
            },
        }
    }
}
