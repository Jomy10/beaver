use crate::BeaverRubyError;

mod project_accessor;
mod target_accessor;
mod project;
mod target;
pub(crate) mod dependency;
mod build_dir;
mod pre;
mod command;

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    project_accessor::register(ruby)?;
    target_accessor::register(ruby)?;
    project::register(ruby)?;
    target::register(ruby)?;
    dependency::register(ruby)?;
    build_dir::register(ruby)?;
    pre::register(ruby)?;
    command::register(ruby)?;

    Ok(())
}

pub(crate) struct Arg<'a, T> {
    name: &'a str,
    value: Option<T>,
}

impl<'a, T> Arg<'a, T> {
    pub fn new(name: &'a str) -> Self {
        Arg { name, value: None }
    }

    pub fn set(&mut self, value: T) -> crate::Result<()> {
        if self.value.is_none() {
            self.value = Some(value);
            Ok(())
        } else {
            Err(BeaverRubyError::ArgumentError(format!("Argument `{}` specified more than once", self.name)))
        }
    }

    pub fn get(self) -> crate::Result<T> {
        match self.value {
            Some(value) => Ok(value),
            None => Err(BeaverRubyError::ArgumentError(format!("Argument `{}` not specified", self.name)))
        }
    }

    pub fn get_opt(self) -> Option<T> {
        self.value
    }
}
