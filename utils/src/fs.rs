use std::io;
use std::path::Path;

#[inline]
#[cfg(unix)]
pub fn symlink_dir(
    original: impl AsRef<Path>,
    link: impl AsRef<Path>
) -> io::Result<()> {
    std::os::unix::fs::symlink(original, link)
}

/// # Limitations
/// Windows treats symlink creation as a privileged action, therefore this function is
/// likely to fail unless the user makes changes to their system to permit symlink creation.
/// Users can try enabling Developer Mode, granting the SeCreateSymbolicLinkPrivilege privilege,
/// or running the process as an administrator.
#[inline]
#[cfg(all(windows, not(feature = "junctions")))]
pub fn symlink_dir(
    original: impl AsRef<Path>,
    link: impl AsRef<Path>
) -> io::Result<()> {
    std::os::windows::fs::symlink_dir(original, link)
}

#[inline]
#[cfg(all(windows, feature = "junctions"))]
pub fn symlink_dir(
    original: impl AsRef<Path>,
    link: impl AsRef<Path>
) -> io::Result<()> {
    std::os::windows::fs::junction_point(original, link)
}

#[inline]
#[cfg(target_os = "wasi")]
pub fn symlink_dir(
    original: impl AsRef<Path>,
    link: impl AsRef<Path>
) -> io::Result<()> {
    std::os::wasi::symlink_path(original, link)
}
