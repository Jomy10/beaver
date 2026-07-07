use utils::UnsafeSendable;
use beaver::phase_hook::{Phase, PhaseHookTrigger};

use crate::{BeaverRubyError, CTX};

fn register_phase_hook(args: &[magnus::Value], trigger: PhaseHookTrigger) -> Result<(), magnus::Error> {
    let args = magnus::scan_args::scan_args::<
        (magnus::Value,), // required (phase name)
        (),
        // (magnus::Value,), // TODO: check optional (proc)
        (), // splat
        (), // trailing
        (), // keyword
        magnus::block::Proc,
    >(args)?;

    let context = &CTX.get().unwrap().context();

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
        let ctx = &CTX.get().unwrap();
        ctx.block_execute_on(Box::new(move || {
            unsafe { block.value() }.call::<magnus::RArray, magnus::Value>(magnus::RArray::new())
                .map(|_| ())
                .map_err(BeaverRubyError::from)
        })).map_err(|err| Box::new(err) as Box<dyn std::error::Error>)
    }), trigger).map_err(|err| BeaverRubyError::from(err).into())
}

fn pre(args: &[magnus::Value]) -> Result<(), magnus::Error> {
    register_phase_hook(args, PhaseHookTrigger::Pre)
}

fn post(args: &[magnus::Value]) -> Result<(), magnus::Error> {
    register_phase_hook(args, PhaseHookTrigger::Post)
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    ruby.define_global_function("pre", magnus::function!(pre, -1));
    ruby.define_global_function("post", magnus::function!(post, -1));

    Ok(())
}
