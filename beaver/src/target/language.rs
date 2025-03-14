use lazy_static::lazy_static;

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

#[cfg(target_os = "macos")]
lazy_static! {
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
            (OBJC, _) => Some(*OBJC_CFLAGS),
            (OBJCXX, _) => Some(*OBJCXX_CFLAGS),
            (C, _) => None,
            (CXX, _) => None,
            (Rust, _) => None,
            (Swift, _) => None,
        }
    }

    pub fn linker_flags(from: Language, to: Language) -> Option<&'static [&'static str]> {
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
            (Swift, _) => None,
        }
    }
}
