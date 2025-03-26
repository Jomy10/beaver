use std::{fs, io};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use log::*;
use uuid::Uuid;
use zerocopy::IntoBytes;

use crate::BeaverError;

pub struct File<'a> {
    pub filename: &'a str,

    pub mtime: SystemTime,
    pub size: u64,

    #[cfg(any(unix, target_os = "wasi"))]
    pub ino: u64,
    #[cfg(unix)]
    pub mode: u32,
    #[cfg(unix)]
    pub uid: u32,
    #[cfg(unix)]
    pub gid: u32,

    #[cfg(windows)]
    pub file_attrs: u32,

    /// Updated every time the file changed
    pub check_id: Uuid,
    /// True if the file still existed the last time it was checked for changes
    pub exists: bool,
}

impl<'a> File<'a> {
    pub fn new(filename: &'a str) -> crate::Result<File<'a>> {
        let f = fs::File::open(filename)?;
        let meta = f.metadata()?;

        #[cfg(unix)]
        {
            use std::os::unix::fs::MetadataExt;

            Ok(File {
                filename,
                mtime: meta.modified()?,
                size: meta.size(),
                ino: meta.ino(),
                mode: meta.mode(),
                uid: meta.uid(),
                gid: meta.gid(),
                check_id: Uuid::new_v4(),
                exists: true
            })
        }
        #[cfg(windows)]
        {
            use std::os::windows::fs::MetadataExt;

            Ok(File {
                filename,
                mtime: meta.modified(),
                size: meta.file_size(),
                file_attrs: meta.file_attributes(),
                check_id: Uuid::new_v4(),
                exists: true
            })
        }
        #[cfg(target_os = "wasi")]
        {
            use std::os::wasi::fs::MetadataExt;

            Ok(File {
                filename,
                mtime: meta.modified(),
                size: meta.size(),
                ino: meta.ino(),
                check_id: Uuid::new_v4(),
                exists: true
            })
        }
    }
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
#[repr(u8)]
#[allow(unused)]
enum LayoutItem {
    Mtime,
    Size,
    Ino,
    Mode,
    Uid,
    Gid,
    CheckId,
    FileAttrs,
    Exists
}

impl<'a> File<'a> {
    #[cfg(unix)]
    const LAYOUT: &'static [(LayoutItem, usize)] = &[
        (LayoutItem::Mtime, std::mem::size_of::<f64>()),
        (LayoutItem::Size, std::mem::size_of::<u64>()),
        (LayoutItem::Ino, std::mem::size_of::<u64>()),
        (LayoutItem::Mode, std::mem::size_of::<u32>()),
        (LayoutItem::Uid, std::mem::size_of::<u32>()),
        (LayoutItem::Gid, std::mem::size_of::<u32>()),
        (LayoutItem::CheckId, 16),
        (LayoutItem::Exists, 1),
    ];

    #[cfg(windows)]
    const LAYOUT: &'static [(&str, usize)] = &[
        (LayoutItem::Mtime, std::mem::size_of::<f64>()),
        (LayoutItem::Size, std::mem::size_of::<u64>()),
        (LayoutItem::Size, std::mem::size_of::<u32>()),
        (LayoutItem::CheckId, 16),
        (LayoutItem::Exists, 1)
    ];

    #[cfg(target_os = "wasi")]
    const LAYOUT: &'static [(&str, usize)] = &[
        (LayoutItem::Mtime, std::mem::size_of::<f64>()),
        (LayoutItem::Size, std::mem::size_of::<u64>()),
        (LayoutItem::Ino, std::mem::size_of::<u64>()),
        (LayoutItem::CheckId, 16),
        (LayoutItem::Exists, 1),
    ];

    const BYTE_SIZE: usize = {
        let mut t = 0;
        let mut i = 0;
        while i < Self::LAYOUT.len() {
            t += Self::LAYOUT[i].1;
            i += 1;
        }
        t
    };

    /// Returns the layout's start position and size
    const fn layout_item_index(item: LayoutItem) -> (usize, usize) {
        let mut start = 0;
        let mut i = 0;
        while i < Self::LAYOUT.len() {
            if (Self::LAYOUT[i].0 as u8) == (item as u8) {
                return (start, Self::LAYOUT[i].1);
            }
            start += Self::LAYOUT[i].1;
            i += 1;
        }
        panic!("Item does not exist in the layout");
    }

    pub fn to_bytes(&self) -> crate::Result<Vec<u8>> {
        let mtime = self.mtime.duration_since(UNIX_EPOCH)?;

        let mut res = Vec::new();
        res.reserve(Self::BYTE_SIZE);

        res.extend_from_slice(mtime.as_secs_f64().as_bytes());
        res.extend_from_slice(self.size.as_bytes());
        #[cfg(any(unix, target_os = "wasi"))]
        res.extend_from_slice(self.ino.as_bytes());
        #[cfg(unix)]
        res.extend_from_slice(self.mode.as_bytes());
        #[cfg(unix)]
        res.extend_from_slice(self.uid.as_bytes());
        #[cfg(unix)]
        res.extend_from_slice(self.gid.as_bytes());
        #[cfg(windows)]
        res.extend_from_slice(self.file_attrs.as_bytes());
        res.extend_from_slice(self.check_id.as_bytes());
        res.push(if self.exists {1} else {0});

        return Ok(res);
    }

    pub fn from_bytes(bytes: impl AsRef<[u8]>, filename: &'a str) -> crate::Result<Self> {
        let bytes = bytes.as_ref();

        let (mut start, mut size) = const { Self::layout_item_index(LayoutItem::Mtime) };
        let mtime = f64::from_ne_bytes(bytes[start..start+size].try_into().unwrap());
        let dur = Duration::try_from_secs_f64(mtime)?;
        let mtime = match SystemTime::UNIX_EPOCH.checked_add(dur) {
            Some(time) => Ok(time),
            None => Err(BeaverError::SystemTimeConversionError),
        }?;
        (start, size) = const { Self::layout_item_index(LayoutItem::Size) };
        let _size = u64::from_ne_bytes(bytes[start..start+size].try_into().unwrap());

        #[cfg(any(unix, target_os = "wasi"))]
        let ino = {
            (start, size) = const { Self::layout_item_index(LayoutItem::Ino) };
            u64::from_ne_bytes(bytes[start..start+size].try_into().unwrap())
        };
        #[cfg(unix)]
        let mode = {
            (start, size) = const { Self::layout_item_index(LayoutItem::Mode) };
            u32::from_ne_bytes(bytes[start..start+size].try_into().unwrap())
        };
        #[cfg(unix)]
        let uid = {
            (start, size) = const { Self::layout_item_index(LayoutItem::Uid) };
            u32::from_ne_bytes(bytes[start..start+size].try_into().unwrap())
        };
        #[cfg(unix)]
        let gid = {
            (start, size) = const { Self::layout_item_index(LayoutItem::Gid) };
            u32::from_ne_bytes(bytes[start..start+size].try_into().unwrap())
        };
        #[cfg(windows)]
        let file_attrs = {
            (start, size) = const { Self::layout_item_index(LayoutItem::FileAttrs) };
            u32::from_ne_bytes(bytes[start..start+size].try_into().unwrap())
        };
        (start, size) = const { Self::layout_item_index(LayoutItem::CheckId) };
        let check_id = Uuid::from_bytes(bytes[start..start+size].try_into().unwrap());
        (start, _) = const { Self::layout_item_index(LayoutItem::Exists) };
        let exists = bytes[start] > 0;

        #[cfg(unix)]
        return Ok(Self {
            filename,
            mtime, size: _size, ino, mode, uid, gid,
            check_id,
            exists
        });
        #[cfg(target_os = "wasi")]
        return Ok(Self {
            filename,
            mtime, size: _size, ino,
            check_id,
            exists
        });
        #[cfg(windows)]
        return Ok(Self {
            filename,
            mtime, size: _size, file_attrs,
            check_id,
            exists
        });
    }

    pub fn check_id_from_bytes(bytes: impl AsRef<[u8]>) -> Uuid {
        let bytes = bytes.as_ref();
        let (start, size) = const { Self::layout_item_index(LayoutItem::CheckId) };
        let check_id = Uuid::from_bytes(bytes[start..start+size].try_into().unwrap());
        return check_id;
    }

    /// Returns whether the file has changed since last invocation and updates self if it has
    pub fn changed(&mut self) -> crate::Result<bool> {
        let f = match fs::File::open(&self.filename) {
            Ok(f) => f,
            Err(err) => {
                if err.kind() == io::ErrorKind::NotFound {
                    if !self.exists {
                        return Ok(false);
                    }
                    self.exists = false;
                    self.check_id = Uuid::new_v4();
                    return Ok(true);
                } else {
                    return Err(err.into());
                }
            }
        };

        let mut changed = false;
        let meta = f.metadata()?;

        let modified = meta.modified()?;
        if modified.duration_since(UNIX_EPOCH)?.as_secs_f64() != self.mtime.duration_since(UNIX_EPOCH)?.as_secs_f64() {
            self.mtime = modified;
            changed = true;
        }

        if !self.exists {
            self.exists = true;
            changed = true;
        }

        #[cfg(any(unix, target_os = "wasi"))] {
            #[cfg(unix)]
            use std::os::unix::fs::MetadataExt;
            #[cfg(target_os = "wasi")]
            use std::os::wasi::fs::MetadataExt;

            if meta.size() != self.size {
                self.size = meta.size();
                changed = true;
            }

            if meta.ino() != self.ino {
                self.ino = meta.ino();
                changed = true;
            }
        }

        #[cfg(windows)] {
            use std::os::windows::fs::MetadataExt;

            if meta.file_size() != self.size {
                self.size = meta.file_size();
                changed = true;
            }
        }

        #[cfg(unix)] {
            use std::os::unix::fs::MetadataExt;

            if meta.mode() != self.mode {
                self.mode = meta.mode();
                changed = true;
            }

            if meta.uid() != self.uid {
                self.uid = meta.uid();
                changed = true;
            }

            if meta.gid() != self.gid {
                self.gid = meta.gid();
                changed = true;
            }
        }

        if changed {
            self.check_id = Uuid::new_v4();
        }

        return Ok(changed);
    }
}

pub struct ConcreteFileKey<'a> {
    pub context: &'a str,
    pub filename: &'a str,
}

impl<'a> ConcreteFileKey<'a> {
    pub fn to_bytes(&self) -> Vec<u8> {
        let byte_size = self.context.len() + self.filename.len() + 2 * std::mem::size_of::<usize>();
        let mut out = Vec::new();
        out.reserve(byte_size);

        out.extend(self.context.len().as_bytes());
        out.extend(self.context.as_bytes());
        out.extend(self.filename.len().as_bytes());
        out.extend(self.filename.as_bytes());

        return out;
    }

    pub fn from_bytes(bytes: &'a [u8]) -> Self {
        let mut end = std::mem::size_of::<usize>();
        let context_len = usize::from_ne_bytes(bytes[0..end].try_into().unwrap());
        let mut start = end;
        end += context_len;
        let context = unsafe { str::from_utf8_unchecked(&bytes[start..end]) };
        start = end;
        end += std::mem::size_of::<usize>();
        let filename_len = usize::from_ne_bytes(bytes[start..end].try_into().unwrap());
        start = end;
        end += filename_len;
        let filename = unsafe { str::from_utf8_unchecked(&bytes[start..end]) };

        ConcreteFileKey {
            context,
            filename,
        }
    }
}

pub struct ConcreteFileData {
    pub check_id: Uuid,
}

impl ConcreteFileData {
    pub fn as_bytes(&self) -> &[u8; 16] {
        self.check_id.as_bytes()
    }

    #[allow(unused)]
    pub fn from_bytes(bytes: &[u8]) -> Self {
        Self {
            check_id: Uuid::from_bytes(bytes.try_into().unwrap())
        }
    }

    pub fn check_id_from_bytes(bytes: &[u8]) -> &Uuid {
        Uuid::from_bytes_ref(bytes.try_into().unwrap())
    }
}
