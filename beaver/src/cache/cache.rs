use std::collections::HashSet;
use std::fs;
use std::path::Path;
use std::sync::{Mutex, RwLock};

use futures_lite::future;
use log::trace;
use ormlite::sqlite::{SqlitePool, SqliteConnection};
use ormlite::model::*;
use uuid::Uuid;

use crate::cache::models;
use crate::BeaverError;

#[derive(Debug)]
pub struct Cache {
    pool: SqlitePool,
    /// Set of files that were updated
    changed_set: Mutex<HashSet<String>>,
}

impl Cache {
    #[tokio::main]
    pub async fn new(file: &Path) -> crate::Result<Self> {
        if !file.exists() {
            fs::File::create(file)?;
        }

        let Some(file) = file.as_os_str().to_str() else {
            return Err(BeaverError::NonUTF8OsStr(file.as_os_str().to_os_string()));
        };
        // let mut conn = SqliteConnection::connect(file).await.map_err(|err| BeaverError::SQLError(err))?;
        let conns = SqlitePool::connect(file).await.map_err(|err| BeaverError::SQLError(err))?;
        let mut conn = conns.acquire().await.map_err(|err| BeaverError::SQLError(err))?;

        models::ConcreteFile::create_if_not_exists(&mut conn).await?;
        models::File::create_if_not_exists(&mut conn).await?;

        trace!("Opened database pool {}", conns.size());

        Ok(Cache {
            pool: conns,
            changed_set: Mutex::new(HashSet::new()),
        })
    }

    /// Check if a file changed
    #[tokio::main]
    pub async fn file_changed(&mut self, file: &Path, context: &str) -> crate::Result<bool> {
        let Some(filename) = file.as_os_str().to_str() else {
            return Err(BeaverError::NonUTF8OsStr(file.as_os_str().to_os_string()));
        };
        let context = context.to_string() + filename;

        let file_row = models::File::fetch_one(filename, &self.pool);
        let cfile_row = models::ConcreteFile::fetch_one(&context, &self.pool);

        // Insert/update file record
        let check_id: Uuid = match file_row.await {
            Ok(mut file_row) => {
                let mut update_set = self.changed_set.lock().map_err(|err| BeaverError::LockError(err.to_string()))?;
                let changed = file_row.changed(&mut update_set)?;
                drop(update_set);
                if changed {
                    let check_id = file_row.check_id;
                    file_row.update_all_fields(&self.pool).await.map_err(|err| {
                        match err {
                            ormlite::Error::SqlxError(error) => BeaverError::SQLError(error),
                            ormlite::Error::TokenizationError(tokenizer_error) => panic!("Unexpected error (bug): {}", tokenizer_error),
                            ormlite::Error::OrmliteError(err) => BeaverError::ORMLiteError(err),
                        }
                    })?;

                    Ok(check_id)
                } else {
                    Ok(file_row.check_id)
                }
            },
            Err(err) => {
                match err {
                    ormlite::Error::SqlxError(error) => match error {
                        sqlx::Error::RowNotFound => {
                            let file = models::File::new(filename)?;
                            let check_id = file.check_id;
                            let mut changed_set = self.changed_set.lock().map_err(|err| BeaverError::LockError(err.to_string()))?;
                            changed_set.insert(filename.to_string());
                            drop(changed_set);
                            file.insert(&self.pool).await.map_err(|err| match err {
                                ormlite::Error::SqlxError(error) => BeaverError::SQLError(error),
                                ormlite::Error::TokenizationError(tokenizer_error) => panic!("Unexpected error (bug): {}", tokenizer_error),
                                ormlite::Error::OrmliteError(err) => BeaverError::ORMLiteError(err),
                            })?;
                            Ok(check_id)
                        },
                        error => Err(BeaverError::SQLError(error)),
                    },
                    ormlite::Error::TokenizationError(tokenizer_error) => panic!("Unexpected error (bug): {}", tokenizer_error),
                    ormlite::Error::OrmliteError(err) => Err(BeaverError::ORMLiteError(err)),
                }
            }
        }?;

        // Insert/fetch ConcreteFile record
        let (cfile, inserted) = match cfile_row.await {
            Ok(cfile) => Ok((cfile, false)),
            Err(err) => match err {
                ormlite::Error::SqlxError(error) => match error {
                    sqlx::Error::RowNotFound => {
                        let cfile = models::ConcreteFile::new(&context, filename, check_id)?;
                        cfile.clone().insert(&self.pool).await.map_err(|err| {
                            match err {
                                ormlite::Error::SqlxError(error) => BeaverError::SQLError(error),
                                ormlite::Error::TokenizationError(tokenizer_error) => panic!("Unexpected error (bug): {}", tokenizer_error),
                                ormlite::Error::OrmliteError(err) => BeaverError::ORMLiteError(err),
                            }
                        })?;
                        Ok((cfile, true))
                    },
                    err => Err(BeaverError::SQLError(err))
                },
                ormlite::Error::TokenizationError(tokenizer_error) => panic!("Unexpected error (bug): {}", tokenizer_error),
                ormlite::Error::OrmliteError(err) => Err(BeaverError::ORMLiteError(err)),
            }
        }?;

        if inserted {
            trace!("{} -> changed (new file)", &filename);
            return Ok(true);
        }

        if cfile.check_id != check_id {
            trace!("{} -> changed", &filename);
            cfile.update_partial()
                .check_id(check_id)
                .update(&self.pool).await
                .map_err(|err| match err {
                    ormlite::Error::SqlxError(error) => BeaverError::SQLError(error),
                    ormlite::Error::TokenizationError(tokenizer_error) => panic!("Unexpected error (bug): {}", tokenizer_error),
                    ormlite::Error::OrmliteError(err) => BeaverError::ORMLiteError(err),
                })?;
            Ok(true)
        } else {
            trace!("{} -> unchanged", &filename);
            Ok(false)
        }
    }
}

#[cfg(test)]
mod tests {
    use std::fs::File;
    use std::io::Write;

    use ormlite::Model;

    use crate::cache::models;

    use super::Cache;

    #[test]
    fn file_changed() {
        let mut clog = colog::default_builder();
        clog.filter(None, log::LevelFilter::Trace);
        clog.init();

        let dir = tempdir::TempDir::new("be.jonaseveraert.beaver.tests.cache.file_changed").unwrap();
        eprintln!("{:?}", dir);

        let file_path = dir.path().join("file");
        let mut file = File::create(&file_path).unwrap();

        let mut cache = Cache::new(&dir.path().join("cache")).unwrap();

        let ctx = "test";

        assert_eq!(cache.file_changed(&file_path, ctx).unwrap(), true);
        assert_eq!(cache.file_changed(&file_path, ctx).unwrap(), false);
        file.write("test".as_bytes()).unwrap();
        // file changes are only picked up the next time beaver is run
        let mut cache = Cache::new(&dir.path().join("cache")).unwrap();
        assert_eq!(cache.file_changed(&file_path, ctx).unwrap(), true);
        assert_eq!(cache.file_changed(&file_path, ctx).unwrap(), false);
        file.write("test".as_bytes()).unwrap();
        assert_eq!(cache.file_changed(&file_path, ctx).unwrap(), false);
        let mut cache = Cache::new(&dir.path().join("cache")).unwrap();
        assert_eq!(cache.file_changed(&file_path, ctx).unwrap(), true);
        assert_eq!(cache.file_changed(&file_path, ctx).unwrap(), false);
    }
}
