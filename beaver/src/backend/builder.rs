use std::path::Path;

pub trait BackendBuilder<'a>: Send + Sync + std::fmt::Debug {
    fn add_rule(&mut self, rule: &'a Rule);
    fn get_rule(&self, name: &str) -> Option<&Rule>;
    fn has_rule(&self, name: &str) -> bool;
    fn add_rule_if_not_exists(&mut self, rule: &'a Rule) {
        if !self.has_rule(&rule.name) {
            self.add_rule(rule);
        }
    }

    type Scope: BackendBuilderScope;

    // could be &self maybe
    fn new_scope(&mut self) -> Self::Scope;
    fn apply_scope(&mut self, scope: Self::Scope);

    fn build(self) -> String;
}

pub trait BackendBuilderScope: std::fmt::Debug {
    fn add_step(&mut self, step: &BuildStep) -> crate::Result<()>;

    // fn as_any(&self) -> &dyn Any;
}

#[derive(Debug)]
pub struct Rule {
    pub name: &'static str,
    pub options: Vec<(&'static str, &'static str)>,
}

#[derive(Debug)]
pub enum BuildStep<'a> {
    Phony {
        name: &'a str,
        args: &'a [&'a str],
        dependencies: &'a [&'a str]
    },
    Build {
        rule: &'a Rule,
        output: &'a Path,
        input: &'a [&'a Path],
        dependencies: &'a [&'a str],
        options: &'a [(&'a str, &'a str)],
    }
}
