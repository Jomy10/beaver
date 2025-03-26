use std::borrow::Cow;
use std::collections::{HashSet, LinkedList};
use std::path::Path;
use std::sync::Mutex;

use log::*;
use uuid::Uuid;
use zerocopy::IntoBytes;

use crate::BeaverError;
use super::data::*;

#[derive(Debug)]
pub struct Cache {
    _db: sled::Db,
    /// One file per actual file
    files: sled::Tree,
    /// Files occur multiple times, at most once per context
    concrete_files: sled::Tree,
    file_update_list: Mutex<HashSet<String>>,
}

impl Cache {
    pub fn new(file: &Path) -> crate::Result<Self> {
        let db = sled::open(file)?;
        let files = db.open_tree(b"files")?;
        let concrete_files = db.open_tree(b"concrete_files")?;

        Ok(Self {
            _db: db,
            files,
            concrete_files,
            file_update_list: Mutex::new(HashSet::new())
        })
    }

    fn get_file<'a>(&self, filename: &'a str) -> crate::Result<Option<File<'a>>> {
        let file_bytes = self.files.get(filename)?;
        if let Some(bytes) = file_bytes {
            File::from_bytes(bytes, filename).map(|f| Some(f))
        } else {
            Ok(None)
        }
    }

    /// Returns the check id
    fn update_file(&self, filename: &str) -> crate::Result<Uuid> { // TODO -> Cow
        let mut update_list = self.file_update_list.lock().map_err(|err| BeaverError::LockError(err.to_string()))?;
        if update_list.contains(filename) {
            return self.get_file(filename).map(|file| file.expect("cannot be None").check_id);
        }

        let check_id = if let Some(mut file) = self.get_file(filename)? {
            if file.changed()? {
                self.files.insert(filename, file.to_bytes()?)?;
            }
            file.check_id
        } else {
            let file = File::new(filename)?;
            self.files.insert(filename, file.to_bytes()?)?;
            file.check_id
        };

        update_list.insert(filename.to_string());

        Ok(check_id)
    }

    /// Returns true if any file changed inside of this context
    pub fn files_changed_in_context(&self, context: &str) -> crate::Result<bool> {
        trace!("Checking file context {}", context);

        let mut context_prefix = context.len().as_bytes().to_vec();
        context_prefix.extend(context.as_bytes());

        let mut concrete_file_batch = sled::Batch::default();
        let mut any_changed = false;

        for file in self.concrete_files.scan_prefix(context_prefix) {
            let (keyd, datad) = file?;
            let key = ConcreteFileKey::from_bytes(&keyd);
            let ccheck_id = ConcreteFileData::check_id_from_bytes(&datad);

            let check_id = self.update_file(key.filename)?;
            if *ccheck_id != check_id {
                concrete_file_batch.insert(keyd, ConcreteFileData { check_id }.as_bytes());
                any_changed = true;
            }
        }

        self.concrete_files.apply_batch(concrete_file_batch)?;

        Ok(any_changed)
    }

    /// set all files in a context, removing any old files
    pub fn set_all_files<'a>(&self, files: impl Iterator<Item = &'a Path>, context: &str) -> crate::Result<()> {
        trace!("Adding file context {}", context);

        let mut context_prefix = context.len().as_bytes().to_vec();
        context_prefix.extend(context.as_bytes());

        let mut new_files = files.map(|path| {
            if let Some(str) = path.to_str() {
                Ok(str)
            } else {
                Err(BeaverError::NonUTF8OsStr(path.as_os_str().to_os_string()))
            }
        }).collect::<crate::Result<Vec<&str>>>()?;

        let mut concrete_file_batch = sled::Batch::default();

        // Check files already in context
        // sled can be parallelized
        for file in self.concrete_files.scan_prefix(context_prefix) {
            let (keyd, datad) = file?;
            let key = ConcreteFileKey::from_bytes(&keyd);
            let ccheck_id = ConcreteFileData::check_id_from_bytes(&datad);

            let check_id = self.update_file(key.filename)?;
            if let Some(idx) = new_files.iter().position(|file| *file == key.filename) {
                new_files.swap_remove(idx);
                if *ccheck_id != check_id {
                    concrete_file_batch.insert(keyd, ConcreteFileData { check_id }.as_bytes());
                }
            } else {
                concrete_file_batch.remove(keyd);
            }
        }

        for file in new_files {
            let key = ConcreteFileKey {
                context,
                filename: file,
            };
            let check_id = self.update_file(file)?;
            let data = ConcreteFileData { check_id };
            concrete_file_batch.insert(key.to_bytes(), data.as_bytes());
        }

        self.concrete_files.apply_batch(concrete_file_batch)?;

        Ok(())
    }

    pub fn remove_context(&self, context: &str) -> crate::Result<()> {
        let mut context_prefix = context.len().as_bytes().to_vec();
        context_prefix.extend(context.as_bytes());

        let mut remove_batch = sled::Batch::default();

        for file in self.concrete_files.scan_prefix(context_prefix) {
            let (key, _) = file?;
            remove_batch.remove(key);
        }

        self.concrete_files.apply_batch(remove_batch)?;

        Ok(())
    }
}
