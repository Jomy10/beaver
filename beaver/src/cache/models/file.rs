use std::collections::HashSet;
use std::fs;
// TODO: support for Windows/Non-unix
#[cfg(unix)]
use std::os::unix::fs::MetadataExt;

use log::trace;
use ormlite::Model;
use sqlx::sqlite::SqliteTypeInfo;
use sqlx::{SqliteConnection, TypeInfo};
use uuid::Uuid;

use crate::cache::types::{Timespec, UInt};

#[derive(Model, Debug, Clone)]
pub struct File {
    #[ormlite(primary_key)]
    pub filename: String,
    pub mtime: Timespec,
    pub size: UInt,
    pub ino: UInt,
    pub mode: u32,
    pub uid: u32,
    pub gid: u32,

    /// Updated every time the file changed
    pub check_id: Uuid,
}

impl File {
    pub fn new(filename: &str) -> crate::Result<File> {
        let f = fs::File::open(filename)?;
        let meta = f.metadata()?;

        Ok(File {
            filename: filename.to_string(),
            mtime: Timespec(meta.modified()?),
            size: UInt(meta.size()),
            ino: UInt(meta.ino()),
            mode: meta.mode(),
            uid: meta.uid(),
            gid: meta.gid(),
            check_id: Uuid::new_v4(),
        })
    }

    pub async fn create_if_not_exists(conn: &mut SqliteConnection) -> Result<(), sqlx::Error> {
        let str_typeinfo: SqliteTypeInfo = <String as sqlx::Type::<sqlx::Sqlite>>::type_info();
        let timespec_typeinfo: SqliteTypeInfo = <Timespec as sqlx::Type::<sqlx::Sqlite>>::type_info();
        let uint_typeinfo: SqliteTypeInfo = <UInt as sqlx::Type::<sqlx::Sqlite>>::type_info();
        let uuid_typeinfo: SqliteTypeInfo = <Uuid as sqlx::Type::<sqlx::Sqlite>>::type_info();
        let u32_typeinfo: SqliteTypeInfo = <u32 as sqlx::Type::<sqlx::Sqlite>>::type_info();

        let res = sqlx::query(&format!("
CREATE TABLE IF NOT EXISTS file (
    filename {} PRIMARY KEY,
    mtime {},
    size {},
    ino {},
    mode {},
    uid {},
    gid {},
    check_id {}
);
            ",
            str_typeinfo.name(),
            timespec_typeinfo.name(),
            uint_typeinfo.name(),
            uint_typeinfo.name(),
            u32_typeinfo.name(),
            u32_typeinfo.name(),
            u32_typeinfo.name(),
            uuid_typeinfo.name()
        )).execute(conn).await;

        res.map(|val| {
            trace!("{:?}", val);
            ()
        })
    }

    pub fn update_check_id(&mut self) {
        self.check_id = Uuid::new_v4();
    }

    // TODO: execute only once!
    /// When this function returns true, it means that any of the File's metadata
    /// has changed. It updates those fields in the `File` object
    pub fn changed(&mut self, changed_set: &mut HashSet<String>) -> crate::Result<bool> {
        if !changed_set.insert(self.filename.clone()) {
            trace!("{:?} already inserted", self);
            return Ok(false);
        }
        trace!("Inserting {:?}", self);

        let f = fs::File::open(&self.filename)?;
        let meta = f.metadata()?;

        let mut changed = false;

        let modified = meta.modified()?;
        if modified != self.mtime.0 {
            self.mtime = Timespec(modified);
            changed = true
        }

        if meta.size() != self.size.0 {
            self.size = UInt(meta.size());
            changed = true;
        }

        if meta.ino() != self.ino.0 {
            self.ino = UInt(meta.ino());
            changed = true;
        }

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

        if changed {
            self.update_check_id();
        }

        return Ok(changed);
    }
}
