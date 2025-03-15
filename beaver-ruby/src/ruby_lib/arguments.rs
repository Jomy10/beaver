use std::collections::LinkedList;

use log::warn;
use magnus::rb_sys::AsRawValue;
use magnus::value::ReprValue;
use utils::UnsafeSendable;

use crate::{BeaverRubyError, CTX_RC, RBCONTEXT};

// Parse ruby function args for opt/arg
fn parse_ruby_args(args: &[magnus::Value]) -> Result<(Option<String>, Option<String>, Option<magnus::Value>), magnus::Error> {
    let args = magnus::scan_args::scan_args::<
        (String,), // required
        (Option<String>,), // optional
        (), // splat
        (), // trailing
        magnus::RHash, // keyword
        () // block
    >(args)?;

    let mut long_name: Option<String> = None;
    let mut short_name: Option<String> = None;

    if args.required.0.len() == 1 {
        short_name = Some(args.required.0);
    } else {
        long_name = Some(args.required.0);
    }

    if let Some(second_arg) = args.optional.0 {
        if second_arg.len() == 1 {
            if short_name.is_none() {
                short_name = Some(second_arg);
            } else {
                long_name = short_name;
                short_name = Some(second_arg);
            }
        } else {
            if long_name.is_none() {
                long_name = Some(second_arg);
            } else {
                return Err(BeaverRubyError::ArgumentError(format!("Cannot use {} as a short name for `opt`", second_arg)).into());
            }
        }
    }

    let mut default: Option<magnus::Value> = None;
    args.keywords.foreach(|key: magnus::Symbol, value: magnus::Value| {
        match key.name()?.as_ref() {
            "default" => {
                default = Some(value);
                Ok(magnus::r_hash::ForEach::Continue)
            },
            _ => Err(BeaverRubyError::ArgumentError(format!("Invalid argument `{}` for function `opt`", key.to_string())).into()),
        }
    })?;

    return Ok((long_name, short_name, default));
}

fn arg_position(args: &mut LinkedList<String>, full_name: Option<&str>, short_name: Option<&str>) -> Option<usize> {
    for (i, arg) in args.iter().enumerate() {
        if !arg.starts_with("-") { continue }
        if arg.len() == 1 { continue }
        if arg.chars().nth(1).unwrap() == '-' {
            if arg.len() == 2 { continue }
            let Some(full_name) = full_name else { continue };
            let arg = &arg[2..];
            if arg == full_name {
                return Some(i);
            }
        } else {
            let Some(short_name) = short_name else { continue };
            let arg = &arg[1..];
            if arg == short_name {
                return Some(i);
            }
        }
    }

    return None;
}

// TODO: create linked list which can delete an element from a cursor (LinkedList::remove is O(n) because it has to walke the list from the beginning
// if can delete using a cursor, we wouldn't have to walke from the beginning)
fn get_opt(args: &mut LinkedList<String>, full_name: Option<&str>, short_name: Option<&str>) -> crate::Result<Option<String>> {
    if let Some(i) = arg_position(args, full_name, short_name) {
        let arg_len = args.len();
        let arg = args.remove(i);
        if arg_len <= i + 1 {
            return Err(BeaverRubyError::CLIArgumentError(format!("Expected a value for {}", arg)));
        }
        return Ok(Some(args.remove(i)));
    } else {
        Ok(None)
    }
}

fn opt(args: &[magnus::Value]) -> Result<magnus::Value, magnus::Error> {
    #[allow(static_mut_refs)]
    let ctx = unsafe { &CTX_RC.assume_init_ref() }.upgrade().unwrap();

    let (long_name, short_name, default) = parse_ruby_args(args)?;

    let mut args = ctx.args.borrow_mut();
    let value: Option<String> = get_opt(&mut args, long_name.as_deref(), short_name.as_deref())?;
    drop(args);

    if let Some(default) = default {
        let default_value = default.as_raw();
        let default_value_type = unsafe { rb_sys::RB_TYPE(default_value) };

        if let Some(value) = value {
            match default_value_type {
                rb_sys::ruby_value_type::RUBY_T_FLOAT => match value.parse::<f64>() {
                    Ok(f) => Ok(magnus::Float::from_f64(f).as_value()),
                    Err(err) => Err(BeaverRubyError::from(err).into()),
                },
                rb_sys::ruby_value_type::RUBY_T_NIL |
                rb_sys::ruby_value_type::RUBY_T_STRING => Ok(ctx.ruby.str_new(&value).as_value()),
                rb_sys::ruby_value_type::RUBY_T_FIXNUM |
                rb_sys::ruby_value_type::RUBY_T_BIGNUM => match value.parse::<i64>() {
                    Ok(i) => Ok(magnus::Integer::from_i64(i).as_value()),
                    Err(err) => Err(BeaverRubyError::from(err).into()),
                },
                rb_sys::ruby_value_type::RUBY_T_TRUE |
                rb_sys::ruby_value_type::RUBY_T_FALSE => match value.parse::<bool>() {
                    Ok(b) => Ok(match b {
                        true => ctx.ruby.qtrue().as_value(),
                        false => ctx.ruby.qfalse().as_value(),
                    }),
                    Err(err) => Err(BeaverRubyError::from(err).into()),
                },
                rb_sys::ruby_value_type::RUBY_T_SYMBOL => Ok(magnus::Symbol::new(value).as_value()),
                ty => {
                    warn!("Couldn't determine type for `opt`. Default value is {:?} which is not supported, defaulting to string", ty);
                    Ok(ctx.ruby.str_new(&value).as_value())
                }
            }
        } else {
            Ok(default)
        }
    } else {
        if let Some(value) = value {
            Ok(ctx.ruby.str_new(&value).as_value())
        } else {
            Ok(ctx.ruby.qnil().as_value())
        }
    }
}

/// Returns true if present
fn get_flag(args: &mut LinkedList<String>, full_name: Option<&str>, short_name: Option<&str>) -> crate::Result<bool> {
    if let Some(i) = arg_position(args, full_name, short_name) {
        _ = args.remove(i);
        Ok(true)
    } else {
        Ok(false)
    }
}

fn flag(args: &[magnus::Value]) -> Result<magnus::Value, magnus::Error> {
    #[allow(static_mut_refs)]
    let ctx = unsafe { CTX_RC.assume_init_ref() }.upgrade().unwrap();

    let (long_name, short_name, default) = parse_ruby_args(args)?;

    // no-[flag]
    if let Some(default) = default {
        if default.is_nil() || default.is_kind_of(ctx.ruby.class_true_class()) {
            let mut args = ctx.args.borrow_mut();
            let flag_present: bool = get_flag(&mut args, long_name.as_ref().map(|str| "no-".to_string() + str.as_str()).as_deref(), None)?;
            if flag_present {
                return Ok(ctx.ruby.qfalse().as_value());
            }
        }
    }

    let mut args = ctx.args.borrow_mut();
    let flag_present: bool = get_flag(&mut args, long_name.as_deref(), short_name.as_deref())?;
    drop(args);

    if flag_present {
        return Ok(ctx.ruby.qtrue().as_value());
    }

    if let Some(default) = default {
        return Ok(default);
    } else {
        return Ok(ctx.ruby.qfalse().as_value());
    }
}

fn cmd(args: &[magnus::Value]) -> Result<(), magnus::Error> {
    let context = unsafe { &*RBCONTEXT.assume_init() };

    let args = magnus::scan_args::scan_args::<
        (String,), // required
        (), // optional
        (), // splat
        (), // trailing
        (), // keyword
        magnus::block::Proc // block
    >(args)?;

    let cmd_name = args.required.0;
    let proc = UnsafeSendable::new(args.block);

    context.add_command(cmd_name, Box::new(move || {
        unsafe { proc.value() }.call(())
            .map_err(|err| Box::new(BeaverRubyError::from(err)) as Box<dyn std::error::Error>)
            .map(|v| { let _: magnus::Value = v; (); })
    })).map_err(BeaverRubyError::from)?;

    Ok(())
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    ruby.define_global_function("opt", magnus::function!(opt, -1));
    ruby.define_global_function("flag", magnus::function!(flag, -1));
    ruby.define_global_function("cmd", magnus::function!(cmd, -1));

    Ok(())
}
