#[cfg(target_os = "macos")]
mod darwin {
    use std::collections::HashMap;
    use std::mem::MaybeUninit;
    use std::sync::Mutex;

    use target_lexicon::Triple;

    lazy_static::lazy_static! {
        static ref SWIFT_LINKER_FLAGS: Mutex<HashMap<Triple, Box<(Vec<String>, MaybeUninit<Vec<&'static str>>)>>> = Mutex::new(HashMap::new());
    }

    pub fn swift_linker_flags(triple: &Triple) -> &'static [&'static str] {
        let mut all_linker_flags = SWIFT_LINKER_FLAGS.lock().unwrap();
        if all_linker_flags.contains_key(triple) {
            let linker_flags = all_linker_flags.get(triple).unwrap();
            let linker_flags_ptr = Box::as_ptr(&linker_flags);
            drop(all_linker_flags);
            return unsafe { linker_flags_ptr.as_ref().unwrap().1.assume_init_ref().as_slice() };
        } else {
            let mut sdk_paths_lookup = super::super::darwin::sdk_path::get_sdk_paths();
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
}

#[cfg(not(target_os = "macos"))]
mod other {
    use target_lexicon::Triple;

    pub fn swift_linker_flags(triple: &Triple) -> &'static [&'static str] {
        unimplemented!("Can't link to swift on non-apple platforms yet")
    }
}

#[cfg(target_os = "macos")]
pub use darwin::*;
#[cfg(not(target_os = "macos"))]
pub use other::*;
