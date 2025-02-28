use core::ffi;
use std::ffi::CString;
use std::io::Read;
use std::str::FromStr;
use std::{fs, mem};
use std::path::Path;

use log::trace;
use rutie::types::Value;
use rutie::{module, AnyObject, Class, Fixnum, Module, Object};
use utils::str::osstr_to_cstr;

use crate::{ruby_lib, BeaverRubyError};

/// State shared for the duration of the ruby program
#[derive(Debug)]
pub struct RubyContext {
    pub status: i32,
    pub context: beaver::Beaver,
}

module!(GlobalModule);

const INTERNAL_NAME: &str = "BeaverInternal";
const CTXPTR_NAME: &str = "INTERNAL_CTXPTR";

pub(crate) fn get_context<'a>() -> &'a mut RubyContext {
    let module = Module::from_existing(INTERNAL_NAME);
    let ptr_fixnum = module.const_get(CTXPTR_NAME).try_convert_to::<Fixnum>().unwrap();
    let ptr_int = ptr_fixnum.to_i64() as isize;
    let ptr: *mut RubyContext = unsafe { mem::transmute(ptr_int) };
    return unsafe { ptr.as_mut().unwrap() };
}

extern "C" {
    fn ruby_script(str: *const ffi::c_char);
}

pub fn execute(context: beaver::Beaver, script_file: &Path) -> crate::Result<Box<RubyContext>> {
    rutie::VM::init();
    rutie::VM::init_loadpath();

    let c_obj_value: Value = unsafe { rutie::rubysys::rb_cObject.into() };
    let c_obj: AnyObject = c_obj_value.into();
    let mut c_class = c_obj.try_convert_to::<Class>().unwrap();

    // set script name
    let script_name: CString = script_file.file_name()
        .map(|osstr| {
            osstr_to_cstr(osstr)
                .unwrap_or(CString::from_str("beaver").expect("valid utf-8"))
        })
        .unwrap_or(CString::from_str("beaver").expect("valid utf-8"));
    unsafe { ruby_script(script_name.as_ptr()) };


    let mut context = Box::new(RubyContext {
        status: 0,
        context: context,
    });

    // The context will live as long as the VM is alive, because it is inside of `RubyContext`,
    // which will exit the VM on drop
    let context_ptr = Box::as_mut_ptr(&mut context);
    let context_ptr_int: isize = unsafe { mem::transmute(context_ptr) };

    let mut module = Module::new(INTERNAL_NAME);
    module.const_set(CTXPTR_NAME, &Fixnum::new(context_ptr_int as i64));

    ruby_lib::project::load(&mut c_class)?;
    ruby_lib::target::load(&mut c_class)?;

    // Read & execute file
    let mut script_file_p = fs::File::open(script_file).map_err(|err| BeaverRubyError::ScriptFileOpenError(err))?;
    let mut script_contents = String::new();
    script_file_p.read_to_string(&mut script_contents).map_err(|err| BeaverRubyError::ScriptFileReadError(err))?;
    trace!("{}", script_contents);

    rutie::VM::eval(&script_contents).map_err(|err| BeaverRubyError::RubyException(err))?;

    return Ok(context);
}
