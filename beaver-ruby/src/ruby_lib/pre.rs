use utils::UnsafeSendable;
use beaver::phase_hook::Phase;

use crate::{BeaverRubyError, RBCONTEXT};

fn pre(args: &[magnus::Value]) -> Result<(), magnus::Error> {
    let args = magnus::scan_args::scan_args::<
        (magnus::Value,), // required (phase name)
        (),
        // (magnus::Value,), // TODO: check optional (proc)
        (), // splay
        (), // trailing
        (), // keyword
        magnus::block::Proc,
    >(args)?;

    let context = unsafe { &*RBCONTEXT.assume_init() };

    let phase = args.required.0;
    let phase: Phase = if let Some(str) = magnus::RString::from_value(phase) {
        Phase::try_from(unsafe { str.as_str()? }).map_err(BeaverRubyError::from)
    } else if let Some(sym) = magnus::Symbol::from_value(phase) {
        Phase::try_from(sym.name()?.as_ref()).map_err(BeaverRubyError::from)
    } else {
        Err(BeaverRubyError::IncompatibleType(phase, "String or Symbol"))
    }?;

    let block = UnsafeSendable::new(args.block);

    context.add_phase_hook(phase, Box::new(move || {
        unsafe { block.value() }.call::<magnus::RArray, magnus::Value>(magnus::RArray::new())
            .map_err(|err| Box::from(BeaverRubyError::from(err)) as Box<dyn std::error::Error>)
            .map(|_| ())
    })).map_err(|err| BeaverRubyError::from(err).into())
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    ruby.define_global_function("pre", magnus::function!(pre, -1));

    Ok(())
}
