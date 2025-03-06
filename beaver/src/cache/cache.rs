use std::collections::HashSet;
use std::fs::{self};
use std::iter::zip;
use std::path::Path;
use std::sync::Mutex;

use log::trace;
use ormlite::sqlite::SqlitePool;
use ormlite::model::*;
use uuid::Uuid;

use crate::cache::models;
use crate::BeaverError;

use super::models::ConcreteFile;

/// Cache files and monitor changes
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
            fs::File::options()
                .create(true)
                .read(true)
                .write(true)
                .open(file)?;
            // #[cfg(unix)] {
            //     use std::os::unix::fs::PermissionsExt;
            //     let f = fs::File::options()
            //         .create(true)
            //         .open(file)?;
            //     let mut permissions = f.metadata()?.permissions();
            //     permissions.set_mode(0o660);
            //     f.set_permissions(permissions)?;
            // }
            // #[cfg(windows)] {
            //     use std::os::windows::fs::OpenOptionsExt;
            //     let f = fs::File::options()
            //         .acces_mode(??)
            //         .create(true)
            //         .open(file)?;
            // }
            // #[cfg(all(not(windows), not(unix)))] {
            //     // TODO: verify
            //     fs::File::create(file)?;
            // }
        }
        dbg!(file);

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

    /// Updates the `File` record based on the metadata, or inserts it when it does not exist
    /// Returns the current/new check_id
    async fn insert_or_update_file(&self, filename: &str) -> crate::Result<Uuid> {
        let file_row = models::File::fetch_one(&filename, &self.pool);

        // Insert/update file record
        match file_row.await {
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
                            let file = models::File::new(&filename)?;
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
        }
    }

    async fn concrete_file_changed(&self, cfile: &ConcreteFile) -> crate::Result<bool> {
        let check_id = self.insert_or_update_file(&cfile.filename).await?;

        if cfile.check_id != check_id {
            trace!("{} -> changed", &cfile.filename);

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
            trace!("{} -> unchanged", &cfile.filename);

            Ok(false)
        }
    }

    /// Check if a file changed
    #[tokio::main]
    pub async fn file_changed(&self, file: &Path, context: &str) -> crate::Result<bool> {
        let Some(filename) = file.as_os_str().to_str() else {
            return Err(BeaverError::NonUTF8OsStr(file.as_os_str().to_os_string()));
        };
        // let context = context.to_string() + filename;

        // let cfile_row = models::ConcreteFile::fetch_one(&context, &self.pool);
        let cfile_row = models::ConcreteFile::select()
            .where_("context = ? and filename = ?")
            .bind(context)
            .bind(filename)
            .fetch_one(&self.pool);

        // Insert/fetch ConcreteFile record
        let cfile = match cfile_row.await {
            Ok(cfile) => Ok(cfile),
            Err(err) => match err {
                ormlite::Error::SqlxError(error) => match error {
                    sqlx::Error::RowNotFound => {
                        let cfile = models::ConcreteFile::new(&context, filename, Uuid::new_v4())?;
                        cfile.clone().insert(&self.pool).await.map_err(|err| {
                            match err {
                                ormlite::Error::SqlxError(error) => BeaverError::SQLError(error),
                                ormlite::Error::TokenizationError(tokenizer_error) => panic!("Unexpected error (bug): {}", tokenizer_error),
                                ormlite::Error::OrmliteError(err) => BeaverError::ORMLiteError(err),
                            }
                        })?;
                        Ok(cfile)
                    },
                    err => Err(BeaverError::SQLError(err))
                },
                ormlite::Error::TokenizationError(tokenizer_error) => panic!("Unexpected error (bug): {}", tokenizer_error),
                ormlite::Error::OrmliteError(err) => Err(BeaverError::ORMLiteError(err)),
            }
        }?;

        // if cfile.check_id != check_id {
        //     trace!("{} -> changed", &filename);
        //     Ok(true)
        // } else {
        //     trace!("{} -> unchanged", &filename);
        //     Ok(false)
        // }
        self.concrete_file_changed(&cfile).await
    }

    #[tokio::main]
    pub async fn files_changed_in_context(&self, context: &str) -> crate::Result<bool> {
        let cfiles = match ConcreteFile::select()
            .where_("context = ?")
            .bind(context)
            .fetch_all(&self.pool).await
        {
            Ok(cfile) => Ok(cfile),
            Err(ormlite::Error::SqlxError(error)) => match error {
                sqlx::Error::RowNotFound => { return Ok(true); },
                error => Err(BeaverError::SQLError(error))
            },
            Err(ormlite::Error::TokenizationError(tokenizer_error)) => panic!("Unexpected error (bug): {}", tokenizer_error),
            Err(ormlite::Error::OrmliteError(err)) => Err(BeaverError::ORMLiteError(err)),
        }?;

        let mut futures = Vec::with_capacity(cfiles.len());
        for cfile in cfiles.iter() {
            futures.push(self.concrete_file_changed(cfile));
        }

        let mut any_changed = false;
        for future in futures {
            any_changed |= future.await?;
        }

        return Ok(any_changed);
    }

    #[tokio::main]
    pub async fn add_all_files<P: AsRef<Path>>(&self, files: impl Iterator<Item = P>, context: &str) -> crate::Result<()> {
        let files = files.into_iter()
            .map(|file| {
                match std::path::absolute(file) {
                    Ok(absfile) => match absfile.as_os_str().to_str() {
                        Some(str) => Ok(str.to_string()),
                        None => Err(BeaverError::NonUTF8OsStr(absfile.as_os_str().to_os_string()))
                    },
                    Err(err) => Err(err.into())
                }
            }).collect::<Result<Vec<String>, BeaverError>>()?;

        let mut futures = Vec::with_capacity(files.len());
        for file in files.iter() {
            futures.push(self.insert_or_update_file(file))
        }

        let mut check_ids = Vec::with_capacity(files.len());
        for future in futures {
            check_ids.push(future.await?);
        }

        let to_check = zip(files.iter().map(|filename| {
            (
                filename,
                models::ConcreteFile::select()
                    .limit(1)
                    .where_("filename = ? and context = ?")
                    .bind(filename)
                    .bind(context)
                    .fetch_optional(&self.pool)
            )
        }), check_ids);
        let mut to_insert = Vec::new();
        for ((filename, row), check_id) in to_check {
            let row = row.await.map_err(|err| match err {
                ormlite::Error::SqlxError(error) => BeaverError::SQLError(error),
                ormlite::Error::TokenizationError(tokenizer_error) => panic!("Unexpected error (bug): {}", tokenizer_error),
                ormlite::Error::OrmliteError(err) => BeaverError::ORMLiteError(err),
            })?;

            if let Some(row) = row {
                row.update_partial()
                    .check_id(check_id)
                    .update(&self.pool)
                    .await.map_err(|err| {
                        match err {
                            ormlite::Error::SqlxError(error) => BeaverError::SQLError(error),
                            ormlite::Error::TokenizationError(tokenizer_error) => panic!("Unexpected error (bug): {}", tokenizer_error),
                            ormlite::Error::OrmliteError(err) => BeaverError::ORMLiteError(err),
                        }
                    })?;
            } else {
                to_insert.push(models::ConcreteFile::new(context, filename, check_id)?);
            }
        }

        if to_insert.len() > 0 {
            models::ConcreteFile::insert_many(to_insert, &self.pool).await.map_err(|err| match err {
                ormlite::Error::SqlxError(error) => BeaverError::SQLError(error),
                ormlite::Error::TokenizationError(tokenizer_error) => panic!("Unexpected error (bug): {}", tokenizer_error),
                ormlite::Error::OrmliteError(err) => BeaverError::ORMLiteError(err),
            })?;
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use std::fs::File;
    use std::io::Write;

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

        let cache = Cache::new(&dir.path().join("cache")).unwrap();

        let ctx = "test";

        assert_eq!(cache.file_changed(&file_path, ctx).unwrap(), true);
        assert_eq!(cache.file_changed(&file_path, ctx).unwrap(), false);
        file.write("test".as_bytes()).unwrap();
        // file changes are only picked up the next time beaver is run
        let cache = Cache::new(&dir.path().join("cache")).unwrap();
        assert_eq!(cache.file_changed(&file_path, ctx).unwrap(), true);
        assert_eq!(cache.file_changed(&file_path, ctx).unwrap(), false);
        file.write("test".as_bytes()).unwrap();
        assert_eq!(cache.file_changed(&file_path, ctx).unwrap(), false);
        let cache = Cache::new(&dir.path().join("cache")).unwrap();
        assert_eq!(cache.file_changed(&file_path, ctx).unwrap(), true);
        assert_eq!(cache.file_changed(&file_path, ctx).unwrap(), false);
    }
}
