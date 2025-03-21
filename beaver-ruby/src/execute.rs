use std::cell::RefCell;
use std::collections::LinkedList;
use std::mem::MaybeUninit;
use std::ops::Deref;
use std::path::Path;
use std::rc::{self, Rc};

use beaver::Beaver;

use crate::ruby_lib;

pub struct BeaverRubyContext {
    pub context: Box<Beaver>,
    #[allow(unused)]
    cleanup: magnus::embed::Cleanup,
    pub(crate) ruby: magnus::Ruby,
    pub(crate) args: RefCell<LinkedList<String>>
}

impl std::fmt::Debug for BeaverRubyContext {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("BeaverRubyContext { ... }")
    }
}

impl BeaverRubyContext {
    /// Are there any arguments left?
    pub fn has_args(&self) -> bool {
        self.args.borrow().len() > 0
    }

    pub fn args<'a>(&'a self) -> impl Deref<Target = LinkedList<String>> + 'a {
        self.args.borrow()
    }
}

/// Used to access context from ruby
pub(crate) static mut RBCONTEXT: MaybeUninit<*const Beaver> = MaybeUninit::uninit();
/// Used in BeaverRubyError to ensure a Ruby value doesn't outlive BeaverRubyContext
pub(crate) static mut CTX_RC: MaybeUninit<rc::Weak<BeaverRubyContext>> = MaybeUninit::uninit();

/// This function is not thread safe and should only be called once
pub unsafe fn execute_script<P: AsRef<Path>>(script_file: P, args: LinkedList<String>, context: Box<Beaver>) -> crate::Result<Rc<BeaverRubyContext>> {
    let cleanup = unsafe { magnus::embed::init() };
    let ruby = magnus::Ruby::get()?;

    let context = Rc::new(BeaverRubyContext {
        context,
        cleanup,
        ruby,
        args: RefCell::new(args)
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
