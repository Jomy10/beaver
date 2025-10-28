use std::path::Path;

use crate::Beaver;

impl Beaver {
    pub fn files_changed(&self, context: impl AsRef<str>, files: Vec<impl AsRef<Path>>) -> crate::Result<bool> {
        let cache = self.cache()?;
        cache.files_changed_in_context2(context.as_ref(), files)
        // cache.set_all_files(files.iter().map(|f| f.as_ref()), context.as_ref())?;
        // Ok(false)
    }
}
