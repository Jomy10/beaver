//! General darwin utilities used for linker flags and cflags

pub mod sdk_path {
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

    pub fn get_sdk_paths() -> impl DerefMut<Target = SDKPathsLookup> {
        APPLE_SDK_PATHS.lock().unwrap()
    }

    pub struct SDKPathsLookup {
        hm: HashMap<Triple, SDKPaths>,
    }

    impl SDKPathsLookup {
        pub fn get<'a>(&'a mut self, triple: &Triple) -> &'a SDKPaths {
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

    pub struct SDKPaths {
        pub sdk_name: &'static str,
        pub sdk_root: PathBuf,
        #[allow(dead_code)]
        pub sdk_platform_root: PathBuf,
        #[allow(dead_code)]
        pub developer_dir: PathBuf,
        pub toolchain_path: PathBuf,
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
