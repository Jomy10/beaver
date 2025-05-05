use std::ffi::OsString;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{self, Stdio};
use std::sync::OnceLock;

use lazy_static::lazy_static;
use log::warn;
use target_lexicon::{OperatingSystem, Triple};

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

static TARGET_TRIPLE: OnceLock<Triple> = OnceLock::new();

pub fn set_target_triple(triple: Triple) {
    TARGET_TRIPLE.set(triple).unwrap()
}

fn target_triple() -> &'static Triple {
    &TARGET_TRIPLE.get_or_init(|| Triple::host())
}

// Paths to executables installed on the system and used for building
lazy_static! {
    // Tools //

    static ref env_path: Vec<PathBuf> = utils::path().expect("PATH environment variable not defined"); // TODO: do we need a fallback?
    // mainly used for Windows
    static ref env_pathext: Option<Vec<OsString>> = utils::pathext();

    pub static ref ninja: PathBuf = Tool { name: "ninja", ..Default::default() }.find();

    pub static ref cc: PathBuf = match target_triple().operating_system {
        OperatingSystem::Emscripten => Tool { name: "emcc", ..Default::default() }.find(),
        _ => Tool { name: "cc", aliases: Some(&["clang", "gcc", "zig", "icx", "icc"]), env: Some("CC") }.find()
    };
    pub static ref cc_extra_args: Option<&'static [&'static str]> = if cc.file_stem().unwrap() == "zig" { Some(&["cc"]) } else { None };

    pub static ref cxx: PathBuf = match target_triple().operating_system {
        OperatingSystem::Emscripten => Tool { name: "em++", ..Default::default() }.find(),
        _ => Tool { name: "cxx", aliases: Some(&["clang++", "g++", "zig", "icpx", "icpc"]), env: Some("CXX") }.find()
    };
    pub static ref cxx_extra_args: Option<&'static [&'static str]> = if cc.file_stem().unwrap() == "zig" { Some(&["c++"]) } else { None };

    pub static ref objc: &'static Path = cc.as_path();
    pub static ref objcxx: &'static Path = cxx.as_path();
    pub static ref gnustep_config: PathBuf = Tool { name: "gnustep-config", ..Default::default() }.find();
    // see objc_cflags & objcxx_cflags & objc_linkerflags below

    pub static ref ar: PathBuf = match target_triple().operating_system {
        OperatingSystem::Emscripten => Tool { name: "emar", ..Default::default() }.find(),
        _ => Tool { name: "ar", aliases: None, env: Some("AR") }.find(),
    };

    pub static ref pkgconf: PathBuf = Tool { name: "pkgconf", aliases: Some(&["pkg-config", "pkgconfig", "pkg-conf"]), env: Some("PKG_CONFIG") }.find();

    pub static ref sh: PathBuf = Tool { name: "sh", aliases: Some(&["zsh", "bash", "fish"]), env: None }.find();

    pub static ref cmake: PathBuf = Tool { name: "cmake", ..Default::default() }.find();

    pub static ref cargo: PathBuf = Tool { name: "cargo", ..Default::default() }.find();

    pub static ref swift: PathBuf = Tool { name: "swift", ..Default::default() }.find();

    pub static ref netcat: PathBuf = Tool { name: "nc", ..Default::default() }.find();
    pub static ref test: PathBuf = Tool { name: "test", ..Default::default() }.find();
    pub static ref cat: PathBuf = Tool { name: "cat", ..Default::default() }.find();
    pub static ref mkfifo: PathBuf = Tool { name: "mkfifo", ..Default::default() }.find();

    // Tool version //

    /// CC
    pub static ref cc_version: CCVersion = {
        let mut proc = process::Command::new(cc.as_path())
            .stdout(Stdio::piped())
            .stdin(Stdio::piped())
            // .args(["-dM", "-E", "-x", "c", "/dev/null"])
            .args(["-E", "-x", "c", "-"])
            .spawn()
            // .output()
            .unwrap();

        let mut stdin = proc.stdin.take().expect("Failed to take stdin");
        std::thread::spawn(move || {
            stdin.write_all("#if defined(__EMSCRIPTEN__)\nemscripten\n__clang_major__.__clang_minor__.__clang_patchlevel__\n#elif defined(__clang_version__)\nclang\n__clang_major__.__clang_minor__.__clang_patchlevel__\n#elif defined(__INTEL_COMPILER)\nicc\n__INTEL_COMPILER\n#elif defined(__INTEL__LLVM_COMPILER)\nicx\n__INTEL_LLVM_COMPILER\n#else\ngcc\n__VERSION__\n#endif".as_bytes())
                .expect("Failed to pipe");
        });

        let output = proc.wait_with_output().expect("Failed to read stdout");
        let output = String::from_utf8(output.stdout).unwrap();

        let version = output.split("\n")
            .filter(|line| !line.starts_with("#"))
            .map(|line| line.replace(" ", ""))
            .collect::<Vec<String>>();
        let mut version = version.iter()
            .map(|line| line.trim())
            .filter(|line| *line != "");

        let ty = version.next().unwrap();
        let version = version.next().unwrap();

        match ty {
            "clang" => CCVersion::Clang(semver::Version::parse(version).unwrap()),
            "gcc" => CCVersion::Gcc(semver::Version::parse(version).unwrap()),
            "emscripten" => CCVersion::Emscripten(semver::Version::parse(version).unwrap()),
            "icc" => CCVersion::Icc(version.parse::<i32>().unwrap()),
            "icx" => CCVersion::Icx(version.parse::<i32>().unwrap()),
            _ => unreachable!()
        }
    };
}

#[cfg(target_os = "macos")]
lazy_static! {
    pub static ref xcrun: PathBuf = Tool { name: "xcrun", ..Default::default() }.find();
    pub static ref xcode_select: PathBuf = Tool { name: "xcode-select", ..Default::default() }.find();
}

pub enum CCVersion {
    Clang(semver::Version),
    Gcc(semver::Version),
    Emscripten(semver::Version),
    Icc(i32),
    Icx(i32)
}
