use proc_macro::TokenStream;
use syn::parse::Parser;

mod init_descriptor;

/// Provides a macro that generates an initializer for a script using a Descriptor struct
#[proc_macro_attribute]
pub fn init_descriptor(attr: TokenStream, item: TokenStream) -> TokenStream {
    // _ = attr; // TODO: accept renames of struct and init method
    let input = syn::punctuated::Punctuated::<syn::Expr, syn::Token![,]>::parse_terminated
        .parse(attr)
        .unwrap();

    let desc_name = if input.len() > 0 {
        let syn::Expr::Path(path) = &input[0] else {
            panic!("Expected `Expr::Path` for first argument");
        };
        Some(&path.path)
    } else {
        None
    };

    let create_desc_struct = if input.len() > 1 {
        let syn::Expr::Lit(lit) = &input[1] else {
            panic!("Expected `Expr::Lit` for second argument");
        };
        match &lit.lit {
            syn::Lit::Bool(b) => b.value,
            _ => panic!("Expected bool literal")
        }
    } else {
        true
    };

    init_descriptor::macro_impl(item, desc_name, create_desc_struct)
}
