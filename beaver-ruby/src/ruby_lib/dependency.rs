use std::mem;

use log::trace;
use rutie::rubysys::class;
use rutie::types::{Argc, Value, ValueType};
use rutie::util::str_to_cstring;
use rutie::{class, methods, AnyException, AnyObject, Array, Class, Exception, NilClass, Object, RString, Symbol};

use crate::raise;
use crate::rutie_ext::{RbValue, RutieObjExt};

class!(DependencyRef);

fn create_dependency(obj: AnyObject, ty: &str, extra_variables: Option<Vec<(&str, AnyObject)>>) -> DependencyRef {
    match obj.vty() {
        RbValue::RString(str) => {
            let mut dep = Class::from_existing("Dependency").allocate();
            dep.instance_variable_set("@string", str);
            dep.instance_variable_set("@type", Symbol::new(ty));
            if let Some(vars) = extra_variables {
                for var in vars {
                    dep.instance_variable_set(var.0, var.1);
                }
            }
            let res = unsafe { dep.to() };
            return res;
        },
        RbValue::Symbol(sym) => {
            let mut dep = Class::from_existing("Dependency").allocate();
            dep.instance_variable_set("@string", RString::new_utf8(sym.to_str()));
            dep.instance_variable_set("@type", Symbol::new(ty));
            if let Some(vars) = extra_variables {
                for var in vars {
                    dep.instance_variable_set(var.0, var.1);
                }
            }
            return unsafe { dep.to() };
        },
        _ => raise!(Class::from_existing("RuntimeError"), &format!("invalid argument to `dynamic`: {:?}", obj))
    }
}

methods!(
    rutie::Class,
    rtself,

    fn static_fn(obj: rutie::AnyObject) -> DependencyRef {
        let obj = match obj {
            Ok(obj) => obj,
            Err(err) => raise!(err),
        };

        create_dependency(obj, "static", None)
    }

    fn dynamic(obj: rutie::AnyObject) -> DependencyRef {
        let obj = match obj {
            Ok(obj) => obj,
            Err(err) => raise!(err)
        };

        create_dependency(obj, "dynamic", None)
    }

    fn system(obj: rutie::AnyObject) -> DependencyRef {
        let obj = match obj {
            Ok(obj) => obj,
            Err(err) => raise!(err)
        };

        create_dependency(obj, "system", None)
    }
);

pub extern "C" fn pkgconfig(argc: Argc, argv: *const AnyObject, _rtself: AnyObject) -> AnyObject {
    let args = Value::from(0);

    unsafe {
        let p_argv: *const Value = mem::transmute(argv);
        class::rb_scan_args(
            argc,
            p_argv,
            str_to_cstring("*").as_ptr(),
            &args
        )
    };

    let arguments = Array::from(args);
    let mut name: Option<AnyObject> = None;
    let mut version_req: Option<AnyObject> = None;
    // let mut options: Vec<AnyObject> = Vec::new();
    let mut options: Array = Array::new();
    for (i, arg) in arguments.into_iter().enumerate() {
        if i == 0 {
            name = Some(arg);
            continue;
        } else if i == 1 {
            if arg.ty() == ValueType::RString {
                version_req = Some(unsafe { arg.to() });
                continue;
            }
        }

        if arg.ty() != ValueType::Symbol {
            raise!(AnyException::new("ArgumentError", Some("Option arguments to `pkgconfig` should be symbols")));
        }

        options.push(arg);
    }

    let Some(name) = name else {
        raise!(AnyException::new("ArgumentError", Some("No name specified to `pkgconfig`")));
    };

    let extra_variables = Some(vec![
        ("@version_req", version_req.unwrap_or(NilClass::new().to_any_object())),
        ("@options", options.to_any_object()),
    ]);

    create_dependency(name, "pkgconfig", extra_variables).to_any_object()
}

// pub extern "C" fn pkgconfig(obj: rutie::AnyObject) -> DependencyRef {
//     create_dependency(obj, "pkgconfig", Some())
// }


pub fn load(c: &mut rutie::Class) -> crate::Result<()> {
    let mut dependency_ref_klass = Class::new("Dependency", None);
    _ = &mut dependency_ref_klass;

    c.define_method("static", static_fn);
    c.define_method("dynamic", dynamic);
    c.define_method("pkgconfig", pkgconfig);
    c.define_method("pkgconf", pkgconfig);
    c.define_method("system", system);

    Ok(())
}
