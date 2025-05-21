use beaver::target::TargetRef;
use magnus::Module;

use crate::{BeaverRubyError, CTX};

#[magnus::wrap(class = "TargetAccessor")]
pub struct TargetAccessor {
    pub projid: usize,
    pub id: usize,
}

impl TargetAccessor {
    fn run(&self, args: magnus::RArray) -> Result<(), magnus::Error> {
        let context = &CTX.get().unwrap().context;

        let args = args.into_iter().map(|value| {
            match magnus::RString::from_value(value) {
                Some(val) => val.to_string(),
                None => Err(BeaverRubyError::IncompatibleType(value, "String").into()),
            }
        }).collect::<Result<Vec<String>, magnus::Error>>()?;
        context.run(TargetRef { project: self.projid, target: self.id }, args).map_err(|err| BeaverRubyError::from(err))?;

        Ok(())
    }

    fn build(&self) -> Result<(), magnus::Error> {
        let context = &CTX.get().unwrap().context;

        context.build(TargetRef { target: self.id, project: self.projid })
            .map_err(|err| BeaverRubyError::from(err).into())
    }
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    let class = ruby.define_class("TargetAccessor", ruby.class_object())?;
    class.define_method("run", magnus::method!(TargetAccessor::run, 1))?;
    class.define_method("build", magnus::method!(TargetAccessor::build, 0))?;

    return Ok(());
}
