use proc_macro::TokenStream;
use syn::parse::{Parse, ParseStream};
use syn::{parse_macro_input, Token};
use quote::quote;
use syn::punctuated::Punctuated;

struct Attr {
    pub name: syn::Expr,
}

impl Parse for Attr {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        let name: syn::Expr = input.parse()?;
        Ok(Self { name })
    }
}

enum AttrType {
    DescriptorValue(usize, syn::Expr),
    #[allow(unused)] // TODO
    DescriptorDefault(usize, syn::Expr),
}

pub fn macro_impl(item: TokenStream) -> TokenStream {
    let input = parse_macro_input!(item as syn::ItemStruct);
    let mut input2 = input.clone();
    let struct_ident = input.ident.clone();
    let mut descriptor_name = struct_ident.to_string();
    descriptor_name.push_str("Descriptor");
    let descriptor_ident = syn::Ident::new(&descriptor_name, proc_macro2::Span::call_site());
    let vis = input.vis;

    let fields: Vec<(Option<AttrType>, &syn::Field)> = input.fields.iter().map(|field| {
        if let Some((i, attr)) = field.attrs.iter().enumerate().find(|(_, attr)| attr.path().is_ident("descriptor_value")) {
            if let syn::Meta::List(list) = &attr.meta {
                let args = list.parse_args_with(Punctuated::<Attr, Token![,]>::parse_terminated).expect("Error parsing descriptor_value values");
                assert_eq!(args.len(), 1); // TODO: proper error
                let arg = args.first().unwrap();
                (Some(AttrType::DescriptorValue(i, arg.name.clone())), field)
            } else {
                panic!("Expected argument to `descriptor_value`");
            }
        // } else if let Some((i, attr)) = field.attrs.iter().enumerate().find(|(i, attr)| attr.path.is_ident("default")) {
        //     if let syn::Meta::List(list) = &attr.meta {
        //         let args = list.parse_args_with(Punctuated::<Attr, Token![,]>::parse_terminated).expect("Error parsing default values");
        //         assert_eq!(args.len(), 1);
        //         let arg = args.first().unwrap();
        //         (None, Some((i, arg.name.clone())), field) // TODO: enum for first arguments
        //     } else {
        //         panic!("Expected argument to `default`")
        //     }
        } else {
            (None, field)
        }
    }).collect();

    let desc_fields = fields.iter().filter_map(|field_desc| {
        match field_desc.0 {
            None | Some(AttrType::DescriptorDefault(_, _)) => Some(field_desc.1.clone()),
            _ => None
        }
    }).map(|field| {
        let mut field = field;
        field.vis = vis.clone();
        field
    }).collect::<Vec<syn::Field>>();

    let struct_fields = fields.iter().map(|field_desc| {
        match field_desc.0 {
            Some(AttrType::DescriptorDefault(i, _)) | Some(AttrType::DescriptorValue(i, _)) => {
                let mut field = field_desc.1.clone();
                field.attrs.remove(i);
                return field;
            }
            None => field_desc.1.clone()
        }
    }).collect::<Vec<syn::Field>>();

    input2.fields = syn::Fields::Named(syn::parse2::<syn::FieldsNamed>(quote!(
        {
            #(#struct_fields),*
        }
    )).expect("Error removing attributes from struct fields"));

    let field_values = fields.iter().map(|(val, field)| {
        let field_name = field.ident.clone().unwrap();
        match val {
            Some(AttrType::DescriptorValue(_, expr)) => {
                syn::parse2::<syn::FieldValue>(quote! {
                    #field_name: #expr
                }).expect("Error parsing static default field value")
            },
            _ => {
                syn::parse2::<syn::FieldValue>(quote! {
                    #field_name: desc.#field_name
                }).expect("Error parsing field value")
            }
        }
    }).collect::<Vec<syn::FieldValue>>();

    // TODO: generate a default function
    // --> If all fields have a default impl, then implement Default, else implement a function that takes the fields without defaults as arguments

    return quote!(
        #input2

        #vis struct #descriptor_ident {
            #(#desc_fields),*
        }

        impl #struct_ident {
            #vis fn new_desc(desc: #descriptor_ident) -> #struct_ident {
                #struct_ident {
                    #(#field_values),*
                }
            }
        }
    ).into();
}
