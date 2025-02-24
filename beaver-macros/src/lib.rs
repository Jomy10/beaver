use proc_macro::TokenStream;

mod init_descriptor;

/// Provides a macro that generates an initializer for a script using a Descriptor struct
#[proc_macro_attribute]
pub fn init_descriptor(attr: TokenStream, item: TokenStream) -> TokenStream {
    _ = attr; // TODO: accept renames of struct and init method
    init_descriptor::macro_impl(item)
}
