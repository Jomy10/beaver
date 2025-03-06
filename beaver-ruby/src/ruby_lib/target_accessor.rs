use beaver::target::TargetRef;
use magnus::Module;

use crate::{BeaverRubyError, RBCONTEXT};

#[magnus::wrap(class = "TargetAccessor")]
pub struct TargetAccessor {
    pub projid: usize,
    pub id: usize,
}

impl TargetAccessor {
    fn run(&self, args: magnus::RArray) -> Result<(), magnus::Error> {
        let context = unsafe { &*RBCONTEXT.assume_init() };
        let args = args.into_iter().map(|value| {
            match magnus::RString::from_value(value) {
                Some(val) => val.to_string(),
                None => Err(BeaverRubyError::IncompatibleType(value, "String").into()),
            }
        }).collect::<Result<Vec<String>, magnus::Error>>()?;
        context.run(TargetRef { project: self.projid, target: self.id }, args).map_err(|err| BeaverRubyError::from(err))?;

        Ok(())
    }
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    let class = ruby.define_class("TargetAccessor", ruby.class_object())?;
    class.define_method("run", magnus::method!(TargetAccessor::run, 1))?;

    return Ok(());
}
