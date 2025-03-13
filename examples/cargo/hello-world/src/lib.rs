use std::ffi::CString;

#[unsafe(no_mangle)]
pub extern "C" fn get_message() -> *mut std::ffi::c_char {
    CString::into_raw(CString::new("Hello world").expect("valid utf8"))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn destroy_message(str: *mut std::ffi::c_char) {
    unsafe { let _ = CString::from_raw(str); }
}
