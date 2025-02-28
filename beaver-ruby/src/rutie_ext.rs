use std::path::PathBuf;

use rutie::types::ValueType;
use rutie::{AnyException, AnyObject, Array, Class, Exception, Fixnum, Float, Hash, Module, Object, RString, Symbol};

#[allow(unused)]
pub(crate) enum RbValue {
    None,
    Object(AnyObject),
    Class(Class),
    Module(Module),
    Float(Float),
    RString(RString),
    Regexp(AnyObject),
    Array(Array),
    Hash(Hash),
    Struct(AnyObject),
    Bignum(AnyObject),
    File(AnyObject),
    Data(AnyObject),
    Match(AnyObject),
    Complex(AnyObject),
    Rational(AnyObject),
    Nil,
    Bool(bool),
    Symbol(Symbol),
    Fixnum(Fixnum),
    Undef(AnyObject),
    IMemo(AnyObject),
    Node(AnyObject),
    IClass(AnyObject),
    Zombie(AnyObject),
    Mask(AnyObject),
}

pub(crate) trait RutieObjExt: rutie::Object {
    fn vty(&self) -> RbValue {
        use ValueType::*;
        match self.ty() {
            None => RbValue::None,
            Object => RbValue::Object(self.to_any_object()),
            Class => RbValue::Class(unsafe { self.to() }),
            Module => RbValue::Module(unsafe { self.to() }),
            Float => RbValue::Float(unsafe { self.to() }),
            RString => RbValue::RString(unsafe { self.to() }),
            Regexp => RbValue::Regexp(self.to_any_object()),
            Array => RbValue::Array(unsafe { self.to() }),
            Hash => RbValue::Hash(unsafe { self.to() }),
            Struct => RbValue::Struct(self.to_any_object()),
            Bignum => RbValue::Bignum(self.to_any_object()),
            File => RbValue::File(self.to_any_object()),
            Data => RbValue::Data(self.to_any_object()),
            Match => RbValue::Match(self.to_any_object()),
            Complex => RbValue::Complex(self.to_any_object()),
            Rational => RbValue::Rational(self.to_any_object()),
            Nil => RbValue::Nil,
            True => RbValue::Bool(true),
            False => RbValue::Bool(false),
            Symbol => RbValue::Symbol(unsafe { self.to() }),
            Fixnum => RbValue::Fixnum(unsafe { self.to() }),
            Undef => RbValue::Undef(self.to_any_object()),
            IMemo => RbValue::IMemo(self.to_any_object()),
            Node => RbValue::Node(self.to_any_object()),
            IClass => RbValue::IClass(self.to_any_object()),
            Zombie => RbValue::Zombie(self.to_any_object()),
            Mask => RbValue::Mask(self.to_any_object()),
        }
    }
}

impl RutieObjExt for AnyObject {}

pub(crate) trait RutieArrayExt: Object {
    fn to_str_vec(self) -> Result<Vec<String>, AnyException> {
        let arr = self.try_convert_to::<Array>()?;
        arr.into_iter().map(|obj| {
            obj.try_convert_to::<RString>().map(|str| str.to_string())
        }).collect()
    }

    fn to_path_vec(self) -> Result<Vec<PathBuf>, AnyException> {
        let arr = self.try_convert_to::<Array>()?;
        arr.into_iter().map(|obj| {
            obj.try_convert_to::<RString>().map(|str| PathBuf::from(str.to_str()))
        }).collect()
    }
}

impl RutieArrayExt for Array {}

pub(crate) trait RutieExceptionExt {
    fn argerr(str: &str) -> AnyException {
        AnyException::new("ArgumentError", Some(str))
    }
}

impl RutieExceptionExt for AnyException {}
