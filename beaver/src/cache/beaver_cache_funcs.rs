use std::path::Path;

use crate::Beaver;

impl Beaver {
    pub fn files_changed(&self, context: impl AsRef<str>, files: Vec<impl AsRef<Path>>) -> crate::Result<bool> {
        let cache = self.cache()?;
        cache.files_changed_in_context2(context.as_ref(), files)
        // cache.set_all_files(files.iter().map(|f| f.as_ref()), context.as_ref())?;
        // Ok(false)
    }

    pub fn store(&self, var_name: impl AsRef<str>, val: impl AsRef<str>) -> crate::Result<()> {
        self.cache()?.store(var_name.as_ref(), val.as_ref())
    }

    pub fn get(&self, var_name: impl AsRef<str>) -> crate::Result<Option<String>> {
        self.cache()?.get(var_name.as_ref())
    }
}
