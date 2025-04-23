use std::ffi::OsString;
use std::path::{Path, PathBuf};
use std::process;

use lazy_static::lazy_static;
use log::warn;

struct Tool<'a> {
    name: &'a str,
    aliases: Option<&'a [&'a str]>,
    env: Option<&'a str>
}

impl<'a> Tool<'a> {
    fn find(&self) -> PathBuf {
        if let Some(env) = self.env {
            if let Some(path) = std::env::var_os(env) {
                let pathbuf = PathBuf::from(&path);
                if pathbuf.exists() {
                    return pathbuf;
                } else {
                    match path.to_str() {
                        Some(path) => match utils::which(path, env_path.iter(), env_pathext.as_ref().map(|v| v.as_slice())) {
                            Some(path) => return path,
                            None => warn!("Environment variable `{}` does not point to a valid path", env)
                        },
                        None => warn!("Environment variable `{}` contains an invalid UTF-8 string", env)
                    }
                }
            }
        }

        if let Some(path) = utils::which(self.name, env_path.iter(), env_pathext.as_ref().map(|v| v.as_slice())) {
            return path;
        }

        if let Some(aliases) = self.aliases {
            for alias in aliases {
                if let Some(path) = utils::which(alias, env_path.iter(), env_pathext.as_ref().map(|v| v.as_slice())) {
                    return path;
                }
            }
        }

        panic!("Can't find `{}` in path", self.name)
    }
}

impl<'a> Default for Tool<'a> {
    fn default() -> Self {
        Tool {
            name: "",
            aliases: None,
            env: None
        }
    }
}

// Paths to executables installed on the system and used for building
lazy_static! {
    // Tools //

    static ref env_path: Vec<PathBuf> = utils::path().expect("PATH environment variable not defined"); // TODO: do we need a fallback?
    // mainly used for Windows
    static ref env_pathext: Option<Vec<OsString>> = utils::pathext();

    pub static ref ninja: PathBuf = Tool { name: "ninja", ..Default::default() }.find();

    pub static ref cc: PathBuf = Tool { name: "cc", aliases: Some(&["clang", "gcc", "zig", "icx", "icc"]), env: Some("CC") }.find();
    pub static ref cc_extra_args: Option<&'static [&'static str]> = if cc.file_stem().unwrap() == "zig" { Some(&["cc"]) } else { None };

    pub static ref cxx: PathBuf = Tool { name: "cxx", aliases: Some(&["clang++", "g++", "zig", "icpx", "icpc"]), env: Some("CXX") }.find();
    pub static ref cxx_extra_args: Option<&'static [&'static str]> = if cc.file_stem().unwrap() == "zig" { Some(&["c++"]) } else { None };

    pub static ref objc: &'static Path = cc.as_path();
    pub static ref objcxx: &'static Path = cxx.as_path();
    pub static ref gnustep_config: PathBuf = Tool { name: "gnustep-config", ..Default::default() }.find();
    // see objc_cflags & objcxx_cflags & objc_linkerflags below

    pub static ref ar: PathBuf = Tool { name: "ar", aliases: None, env: Some("AR") }.find();

    pub static ref pkgconf: PathBuf = Tool { name: "pkgconf", aliases: Some(&["pkg-config", "pkgconfig", "pkg-conf"]), env: Some("PKG_CONFIG") }.find();

    pub static ref sh: PathBuf = Tool { name: "sh", aliases: Some(&["zsh", "bash", "fish"]), env: None }.find();

    pub static ref cmake: PathBuf = Tool { name: "cmake", ..Default::default() }.find();

    pub static ref cargo: PathBuf = Tool { name: "cargo", ..Default::default() }.find();

    pub static ref swift: PathBuf = Tool { name: "swift", ..Default::default() }.find();
    #[cfg(target_os = "macos")]
    pub static ref xcrun: PathBuf = Tool { name: "xcrun", ..Default::default() }.find();
    #[cfg(target_os = "macos")]
    pub static ref xcode_select: PathBuf = Tool { name: "xcode-select", ..Default::default() }.find();

    pub static ref netcat: PathBuf = Tool { name: "nc", ..Default::default() }.find();
    pub static ref test: PathBuf = Tool { name: "test", ..Default::default() }.find();
    pub static ref cat: PathBuf = Tool { name: "cat", ..Default::default() }.find();
    pub static ref mkfifo: PathBuf = Tool { name: "mkfifo", ..Default::default() }.find();

    // Tool version //

    /// CC
    pub static ref cc_version: CCVersion = {
        let proc = process::Command::new(cc.as_path())
            .args(["-dM", "-E", "-x", "-c", "/dev/null"])
            .output()
            .unwrap();

        let output = String::from_utf8(proc.stdout).unwrap();
        output.split("\n")
            .find_map(|line| {
                if line.starts_with("#define __clang__version__") {
                    Some(CCVersion::Clang(semver::Version::parse(&line["#define __clang__version__".len()..]).unwrap()))
                } else if line.starts_with("#define __VERSION__") {
                    let v = &line["#define __VERSION__".len()..];
                    if v.starts_with("Intel") { // ICC/ICX
                        None
                    } else {
                        Some(CCVersion::Gcc(semver::Version::parse(v).unwrap()))
                    }
                } else if line.starts_with("#define __INTEL_COMPILER") { // ICC
                    Some(CCVersion::Icc(line["#define __INTEL_COMPILER".len()..].parse::<i32>().unwrap()))
                } else if line.starts_with("#define __INTEL_LLVM_COMPILER") {
                    Some(CCVersion::Icx(line["#define __INTEL_LLVM_COMPILER".len()..].parse::<i32>().unwrap()))
                } else {
                    None
                }
            });

        todo!()
    };
}

pub enum CCVersion {
    Clang(semver::Version),
    Gcc(semver::Version),
    Icc(i32),
    Icx(i32)
}
