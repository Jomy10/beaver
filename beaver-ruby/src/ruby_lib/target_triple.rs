use magnus::Module;
use target_lexicon::Triple;

use crate::CTX;

#[magnus::wrap(class = "Triple")]
pub struct TripleWrapper(pub(crate) Triple);

impl TripleWrapper {
    fn to_s(&self) -> magnus::RString {
        magnus::RString::new(&self.0.to_string())
    }

    fn arch(&self) -> magnus::RString {
        magnus::RString::new(self.0.architecture.into_str().as_ref())
    }

    fn vendor(&self) -> magnus::RString {
        magnus::RString::new(self.0.vendor.as_str())
    }

    fn os(&self) -> magnus::RString {
        magnus::RString::new(self.0.operating_system.into_str().as_ref())
    }

    fn abi(&self) -> magnus::RString {
        magnus::RString::new(self.0.environment.into_str().as_ref())
    }

    fn binary_format(&self) -> magnus::RString {
        magnus::RString::new(self.0.binary_format.into_str().as_ref())
    }

    fn endianness(&self) -> magnus::Symbol {
        match self.0.endianness().unwrap() {
            target_lexicon::Endianness::Little => magnus::Symbol::new("little"),
            target_lexicon::Endianness::Big => magnus::Symbol::new("big"),
        }
    }

    fn pointer_width(&self) -> magnus::Fixnum {
        match self.0.pointer_width().unwrap() {
            target_lexicon::PointerWidth::U16 => magnus::Fixnum::from_u64(16).unwrap(),
            target_lexicon::PointerWidth::U32 => magnus::Fixnum::from_u64(32).unwrap(),
            target_lexicon::PointerWidth::U64 => magnus::Fixnum::from_u64(64).unwrap(),
        }
    }
}

pub fn register(ruby: &magnus::Ruby) -> crate::Result<()> {
    let context = &CTX.get().unwrap().context();

    let triple_class = ruby.define_class("Triple", ruby.class_object())?;
    triple_class.define_method("to_s", magnus::method!(TripleWrapper::to_s, 0))?;
    triple_class.define_method("arch", magnus::method!(TripleWrapper::arch, 0))?;
    triple_class.define_method("vendor", magnus::method!(TripleWrapper::vendor, 0))?;
    triple_class.define_method("os", magnus::method!(TripleWrapper::os, 0))?;
    triple_class.define_method("abi", magnus::method!(TripleWrapper::abi, 0))?;
    triple_class.define_method("binary_format", magnus::method!(TripleWrapper::binary_format, 0))?;
    triple_class.define_method("endianness", magnus::method!(TripleWrapper::endianness, 0))?;
    triple_class.define_method("pointer_width", magnus::method!(TripleWrapper::pointer_width, 0))?;

    ruby.define_global_const("TARGET", TripleWrapper(context.target_triple().clone()))?;
    ruby.define_global_const("HOST", TripleWrapper(Triple::host()))?;

    // TODO: move to separate file
    ruby.define_global_const("OPT", context.opt_mode().to_string())?; // TODO: to symbol

    Ok(())
}
