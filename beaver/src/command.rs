use std::collections::HashMap;

pub type Command = Box<dyn FnOnce() -> Result<(), Box<dyn std::error::Error>> + Send>;

pub(crate) struct Commands(pub HashMap<String, Command>);

impl std::fmt::Debug for Commands {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_fmt(format_args!("Commands({} commands)", self.0.len()))
    }
}
