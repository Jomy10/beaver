use target_lexicon::OperatingSystem::{self, *};

use crate::BeaverError;

pub fn dynlib_extension_for_os(os: &OperatingSystem) -> crate::Result<&'static str> {
    match os {
        Unknown | None_ => Err(BeaverError::UnknownTargetOS(os.clone())),
        Aix |
        AmdHsa |
        Bitrig |
        Cloudabi |
        Dragonfly |
        Espidf |
        Freebsd |
        Fuchsia |
        Haiku |
        Horizon |
        Hurd |
        Illumos |
        L4re |
        Linux |
        Netbsd |
        Openbsd |
        Redox |
        Solaris |
        SolidAsp3 |
        VxWorks	// .so or .out dependening on configuration
            => Ok("so"),

        Darwin(_) |
        IOS(_) |
        MacOSX(_) |
        TvOS(_) |
        VisionOS(_) |
        WatchOS(_) |
        XROS(_) => Ok("dylib"),

        Emscripten |
        Nebulet	|
        Wasi |
        WasiP1 |
        WasiP2 => Ok("wasm"),

        Hermit | Uefi => Err(BeaverError::TargetDoesntSupportDynamicLibraries(os.clone())),

        // UEFI	.efi (executables, dynamic linking uncommon)
        Windows => Ok("dll"),

        // Currently not supported/investigated
        Psp | Cuda => Err(BeaverError::UnknownTargetOS(os.clone())),	// .prx

        _ => Err(BeaverError::UnknownTargetOS(os.clone()))
    }
}

pub fn staticlib_extension_for_os(os: &OperatingSystem) -> crate::Result<&'static str> {
    match os {
        Windows => Ok("lib"),

        Emscripten |
        Nebulet	|
        Wasi |
        WasiP1 |
        WasiP2 => Ok("wasm"),

        _ => Ok("a")
    }
}
