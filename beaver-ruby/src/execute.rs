use std::mem::MaybeUninit;
use std::path::Path;
use std::rc::{self, Rc};

use beaver::Beaver;

use crate::ruby_lib;

pub struct BeaverRubyContext {
    pub context: Box<Beaver>,
    #[allow(unused)]
    cleanup: magnus::embed::Cleanup,
    #[allow(unused)]
    ruby: magnus::Ruby,
}

impl std::fmt::Debug for BeaverRubyContext {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("BeaverRubyContext { ... }")
    }
}

/// Used to access context from ruby
pub(crate) static mut RBCONTEXT: MaybeUninit<*const Beaver> = MaybeUninit::uninit();
/// Used in BeaverRubyError to ensure a Ruby value doesn't outlive BeaverRubyContext
pub(crate) static mut CTX_RC: MaybeUninit<rc::Weak<BeaverRubyContext>> = MaybeUninit::uninit();

/// This function is not thread safe and should only be called once
pub unsafe fn execute_script<P: AsRef<Path>>(script_file: P, context: Box<Beaver>) -> crate::Result<Rc<BeaverRubyContext>> {
    let cleanup = unsafe { magnus::embed::init() };
    let ruby = magnus::Ruby::get()?;

    let context = Rc::new(BeaverRubyContext {
        context,
        cleanup,
        ruby
    });
    unsafe { CTX_RC = MaybeUninit::new(Rc::downgrade(&context)) }

    context.ruby.script(script_file.as_ref().file_name().map_or("beaver", |str| str.to_str().unwrap_or("beaver")));

    // We want to be able to access the context from ruby. `context` is thread safe, so this should be fine
    unsafe { RBCONTEXT = MaybeUninit::new(Box::as_ptr(&context.context)); }

    ruby_lib::register(&context.ruby)?;


    context.ruby.require(std::path::absolute(script_file.as_ref())?)?;

    // By constructing this, we assure that `context` and `cleanup` live equally long. `context`
    // uses ruby and ruby uses `context`
    return Ok(context);
}
