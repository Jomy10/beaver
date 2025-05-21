use std::borrow::Cow;
use std::collections::HashMap;

use regex::{Captures, Regex};
use log::*;

#[derive(Default, Debug)]
pub struct PkgConfig<'a> {
    name: Option<Cow<'a, str>>,
    description: Option<Cow<'a, str>>,
    version: Option<Cow<'a, str>>,
    libs: Option<Cow<'a, str>>,
    cflags: Option<Cow<'a, str>>
}

// Parsing //
fn get_capture<'a, 'b>(captures: &'b Captures<'a>, capture_name: &str, str: &'a str) -> &'a str {
    let cap = captures.name(capture_name).unwrap();
    &str[cap.start()..cap.end()]
}

impl<'a> PkgConfig<'a> {
    pub fn parse(file_contents: &'a str) -> crate::Result<PkgConfig<'a>> {
        let mut pkg_config = PkgConfig::default();

        let variable_regex = Regex::new(r"(?<variable_name>\w+)=(?<variable_value>.*)").unwrap();
        let param_regex = Regex::new(r"(?<param_name>\w+):\s*(?<param_value>.*)").unwrap();

        let mut variables = HashMap::new();
        for line in file_contents.split("\n") {
            if let Some(captures) = variable_regex.captures(line) {
                let var_name = get_capture(&captures, "variable_name", line);
                let var_val = get_capture(&captures, "variable_value", line);

                variables.insert(var_name, var_val);
            } else if let Some(captures) = param_regex.captures(line) {
                let param_name = get_capture(&captures, "param_name", line);
                let param_value = get_capture(&captures, "param_value", line);

                match param_name {
                    "Name" => pkg_config.name = Some(Self::parse_value(param_value, &variables)?),
                    "Description" => pkg_config.description = Some(Self::parse_value(param_value, &variables)?),
                    "Version" => pkg_config.version = Some(Self::parse_value(param_value, &variables)?),
                    "Libs" => pkg_config.libs = Some(Self::parse_value(param_value, &variables)?),
                    "Cflags" => pkg_config.cflags = Some(Self::parse_value(param_value, &variables)?),
                    _ => {
                        info!("Unparsed pkg-config parameter '{}: {}'", param_name, param_value);
                    }
                }
            }
        }

        Ok(pkg_config)
    }

    fn parse_value<'b>(value: &'b str, variables: &HashMap<&str, &str>) -> crate::Result<Cow<'b, str>> {
        let variable_regex = Regex::new(r"\$\{[^\}]*\}").unwrap();
        let mut out = String::with_capacity(value.len());

        let mut prev_start = 0;
        for range in variable_regex.find_iter(value) {
            if range.start() != 0 && value.chars().nth(range.start()-1).unwrap() == '\\' {
                continue; // variable is escaped
            }
            out.push_str(&value[prev_start..range.start()]);
            prev_start = range.end();
            let variable_name = &value[range.start() + 2 .. range.end() - 1];
            let Some(v) = variables.get(variable_name) else {
                return Err(crate::Error::UnknownVariable(variable_name.to_string()));
            };
            out.push_str(Self::parse_value(v, variables)?.as_ref());
        }
        if prev_start == 0 {
            return Ok(Cow::Borrowed(value));
        } else {
            out.push_str(&value[prev_start..value.len()]);
            return Ok(Cow::Owned(out));
        }
    }
}

// Accessors //
impl<'a> PkgConfig<'a> {
    pub fn name(&self) -> &Option<Cow<'a, str>> {
        &self.name
    }

    pub fn description(&self) -> &Option<Cow<'a, str>> {
        &self.description
    }

    pub fn version(&self) -> &Option<Cow<'a, str>> {
        &self.version
    }

    pub fn libs(&self) -> &Option<Cow<'a, str>> {
        &self.libs
    }

    pub fn cflags(&self) -> &Option<Cow<'a, str>> {
        &self.cflags
    }
}

// Errors //
pub type Result<T> = std::result::Result<T, crate::Error>;

#[derive(thiserror::Error, Debug, Clone)]
pub enum Error {
    #[error("{0}")]
    UnknownVariable(String),
}

#[cfg(test)]
mod tests {
    use crate::PkgConfig;

    #[test]
    fn test() {
        let pkg_config = PkgConfig::parse(r"
prefix=/usr/local/lib/mylib
includedir=${prefix}/include
libdir=${prefix}/lib

Name: mylib
Description: This is my library
Version: 1.0
Libs: -L${libdir} -lmylib
Cflags: -I${prefix} -I${includedir}
").unwrap();

        dbg!(&pkg_config);

        assert_eq!(pkg_config.name.unwrap().as_ref(), "mylib");
        assert_eq!(pkg_config.description.unwrap().as_ref(), "This is my library");
        assert_eq!(pkg_config.version.unwrap().as_ref(), "1.0");
        assert_eq!(pkg_config.libs.unwrap().as_ref(), "-L/usr/local/lib/mylib/lib -lmylib");
        assert_eq!(pkg_config.cflags.unwrap().as_ref(), "-I/usr/local/lib/mylib -I/usr/local/lib/mylib/include");
    }
}
