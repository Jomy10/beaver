use lazy_static::lazy_static;


#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash)]
pub enum Language {
    C,
    CXX,
    OBJC,
    OBJCXX
}

lazy_static! {
    static ref OBJCXX_TO_C_LINKER_FLAGS: Vec<&'static str> = {
        let mut v = objc_linker_flags.to_vec();
        v.push("-lstdc++");
        v
    };
}

#[cfg(target_os = "macos")]
lazy_static! {
    pub static ref objc_cflags: &'static [&'static str] = &["-x", "objective-c"];
    pub static ref objcxx_cflags: &'static [&'static str] = &["-x", "objective-c++"];
    pub static ref objc_linker_flags: &'static [&'static str] = &["-lobjc"];
}

#[cfg(not(target_os = "macos"))]
lazy_static! {
    pub static ref objc_cflags: &'static [&'static str] = {
        let output = Command::new(gnustep_config)
            .args(["--objc-flags"])
            .output()
            .expect("Failed to get objc-flags from gnustep-config")
            .stdout;
        shlex::bytes::split(output.as_slice())
            .expect(&format!("Couldn't parse arguments `{}`", output))
    };
    pub static ref objcxx_cflags: &'static [&'static str] = objc_cflags;
    pub static ref objc_linker_flags: &'static [&'static str] = {
        let output = Command::new(gnustep_config)
            .args(["--objc-libs", "--base-libs"])
            .output()
            .expect("Failed to get objc-libs from gnustep-config")
            .stdout;
        shlex::bytes::split(output.as_slice())
            .expect(&format!("Couldn't parse arguments `{}`", output))
    };
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
            (OBJC, _) => Some(*objc_cflags),
            (OBJCXX, _) => Some(*objcxx_cflags),
            (C, _) => None,
            (CXX, _) => None,
        }
    }

    pub fn linker_flags(from: Language, to: Language) -> Option<&'static [&'static str]> {
        use Language::*;

        match (from, to) {
            (C, _) => None,

            (CXX, C | OBJC) | (OBJCXX, OBJC) => Some(&["-lstdc++"]),
            (CXX, CXX | OBJCXX) => None,

            (OBJCXX | OBJC, CXX) | (OBJC, C) => Some(*objc_linker_flags),
            (OBJCXX, C) => Some(&OBJCXX_TO_C_LINKER_FLAGS),
            (OBJC, OBJC | OBJCXX) |
            (OBJCXX, OBJCXX) => None,
        }
    }
}
