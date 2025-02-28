use std::collections::HashMap;
use std::fmt::Write;

use crate::backend::{BackendBuilder, BackendBuilderScope, BuildStep, Rule};
use crate::BeaverError;

#[derive(Debug)]
pub struct NinjaBuilder<'a> {
    buffer: String,
    rules: HashMap<&'a str, &'a Rule>
}

impl<'a> NinjaBuilder<'a> {
    pub fn new() -> Self {
        NinjaBuilder {
            buffer: String::new(),
            rules: HashMap::new()
        }
    }
}

impl<'a> BackendBuilder<'a> for NinjaBuilder<'a> {
    fn add_rule(&mut self, rule: &'a Rule) {
        self.rules.insert(&rule.name, rule);

        self.buffer.push_str(&format!("rule {}\n", rule.name));
        for (name, val) in &rule.options {
            self.buffer.push_str(&format!("    {} = {}\n", name, val));
        }
    }

    fn get_rule(&self, name: &str) -> Option<&Rule> {
        self.rules.get(&name).map(|val| *val)
    }

    fn has_rule(&self, name: &str) -> bool {
        self.rules.contains_key(&name)
    }

    fn new_scope(&mut self) -> Box<dyn BackendBuilderScope> {
        Box::new(NinjaBuilderScope::new())
    }

    /// Unsafe because the scope is assumed to be a NinjaBuilderScope
    unsafe fn apply_scope(&mut self, scope: Box<dyn BackendBuilderScope>) {
        let scope = Box::into_raw(scope);
        let scope = Box::from_raw(scope as *mut NinjaBuilderScope);
        self.buffer.push_str(&scope.buffer);
    }

    fn build(self) -> String {
        self.buffer
    }
}

#[derive(Debug)]
pub struct NinjaBuilderScope {
    pub(self) buffer: String
}

impl NinjaBuilderScope {
    fn new() -> Self {
        NinjaBuilderScope { buffer: String::new() }
    }
}

impl NinjaBuilderScope {
    fn write_str(&mut self, str: &str) -> crate::Result<()> {
        self.buffer.write_str(str)
            .map_err(|err| {
                BeaverError::BufferWriteError(err.to_string())
            })
    }

    fn write_fmt(&mut self, args: std::fmt::Arguments<'_>) -> crate::Result<()> {
        self.buffer.write_fmt(args)
            .map_err(|err| {
                BeaverError::BufferWriteError(err.to_string())
            })
    }

    fn write_char(&mut self, c: char) -> crate::Result<()> {
        self.buffer.write_char(c)
            .map_err(|err| {
                BeaverError::BufferWriteError(err.to_string())
            })
    }

    fn write_dependencies(&mut self, deps: &[&str]) -> crate::Result<()> {
        if deps.len() > 0 {
            self.write_str(" || ")?;
            for dep in deps.iter() {
                self.write_str(dep)?;
                self.write_char(' ')?;
            }
        }
        return Ok(());
    }

    fn write_options(&mut self, options: &[(&str, &str)]) -> crate::Result<()> {
        for opt in options {
            self.write_fmt(format_args!("    {} = {}\n", opt.0, opt.1))?;
        }
        return Ok(());
    }
}

impl BackendBuilderScope for NinjaBuilderScope {
    fn add_step(&mut self, step: &crate::backend::BuildStep) -> crate::Result<()> {
        match step {
            BuildStep::Phony { name, args, dependencies } => {
                self.write_fmt(format_args!("build {}: phony {}", name, args.join(" ")))?;
                self.write_dependencies(dependencies)?;
                self.write_char('\n')?;
            },
            BuildStep::Build { rule, output, input, dependencies, options } => {
                self.write_fmt(format_args!(
                    "build {}: {} {}",
                    output.display(),
                    rule.name,
                    input.iter()
                        .map(|f| f.to_str().expect("Path is not UTF-8 encoded"))
                        .fold(String::new(), |acc, path| {
                            let mut acc = acc;
                            acc.push_str(path);
                            acc.push(' ');
                            acc
                        })
                ))?;
                self.write_dependencies(dependencies)?;
                self.write_char('\n')?;
                self.write_options(options)?;
            },
        }

        return Ok(());
    }

    // fn as_any(&self) -> &dyn Any {
    //     self
    // }
}
