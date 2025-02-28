use target_lexicon::OperatingSystem::{self, *};

use crate::BeaverError;

pub fn dynlib_linker_flags_for_os(os: &OperatingSystem) -> crate::Result<&[&str]> {
    match os {
        Unknown | None_ => Err(BeaverError::UnknownTargetOS(os.clone())),
        // I have not thoroughly researched all of these, so if any of them are not working, pull-requests are welcome
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
            => Ok(&["-shared"]),

        Darwin(_) |
        IOS(_) |
        MacOSX(_) |
        TvOS(_) |
        VisionOS(_) |
        WatchOS(_) |
        XROS(_) => Ok(&["-dynamiclib"]),

        Emscripten |
        Nebulet	|
        Wasi |
        WasiP1 |
        WasiP2 => Ok(&[]),

        Hermit | Uefi => Err(BeaverError::TargetDoesntSupportDynamicLibraries(os.clone())),

        // UEFI	.efi (executables, dynamic linking uncommon)
        Windows => todo!("dynamic libraries in windows are currently unsupported"),

        // Currently not supported/investigated
        Psp | Cuda => Err(BeaverError::UnknownTargetOS(os.clone())),	// .prx

        _ => Err(BeaverError::UnknownTargetOS(os.clone()))
    }
}
