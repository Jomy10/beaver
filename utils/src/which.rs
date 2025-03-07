use std::env;
use std::ffi::{OsStr, OsString};
use std::path::PathBuf;

/// Finds the first path found to an executable, if any paths were found
///
/// # Paramters
/// - `paths`: The path environment variable to search in
pub fn which<'a, P: AsRef<OsStr>>(
    cmd: &str,
    paths: impl Iterator<Item = &'a PathBuf>,
    pathext: Option<&[P]>
) -> Option<PathBuf> {
    if let Some(exts) = pathext {
        for path in paths {
            let mut exe = path.join(cmd);
            for ext in exts {
                exe.set_extension(ext);
                if exe.exists() && !exe.is_dir() {
                    return Some(exe);
                }
            }
        }
    } else {
        for path in paths {
            let exe = path.join(cmd);
            if exe.exists() && !exe.is_dir() {
                return Some(exe);
            }
        }
    }

    return None;
}

/// Returns the `PATH` environment variable
pub fn path() -> Option<Vec<PathBuf>> {
    env::var_os("PATH").map(|path| {
        env::split_paths(&path).map(|p| {
            PathBuf::from(p)
        }).collect()
    })
}

/// Returns the `PATHEXT` environment variable
///
/// Can fail on Windows where OsStr is not neceserrily UTF-8
pub fn pathext() -> Option<Vec<OsString>> {
    env::var_os("PATHEXT").map(|pathext| {
        env::split_paths(&pathext).map(|p| {
            p.as_os_str().to_owned()
        }).collect()
    })
}
