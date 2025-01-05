//! API for using indicatif from C

#![allow(unused_parens)]

use std::sync::{Arc, Mutex};
use std::ffi::{self, CStr, CString};
use std::borrow::Cow;

#[repr(C)]
pub enum Stream {
    Stdout = 0,
    Stderr = 1
}

pub struct ProgressIndicators {
    indicators: Mutex<indicatif::MultiProgress>,
    error_string: Mutex<Option<String>>,
    progress_bars: Mutex<Vec<Option<Arc<ProgressBar>>>>,
}

pub struct ProgressBar {
    idx: usize,
    progress_bar: indicatif::ProgressBar,
    indicators: Arc<ProgressIndicators>,
}

impl ProgressIndicators {
    #[inline]
    fn start(stream: Stream) -> Arc<ProgressIndicators> {
        let indicators = indicatif::MultiProgress::new();
        match stream {
            Stream::Stdout => indicators.set_draw_target(indicatif::ProgressDrawTarget::stdout()),
            Stream::Stderr => indicators.set_draw_target(indicatif::ProgressDrawTarget::stderr()),
        }

        let prog = Arc::new(ProgressIndicators {
            indicators: Mutex::new(indicators),
            error_string: Mutex::new(None),
            progress_bars: Mutex::new(Vec::new()),
        });
        return prog;
    }

    #[inline]
    fn tick(self: &Arc<ProgressIndicators>) {
        self.progress_bars.lock().unwrap().iter().for_each(|bar| {
            bar.as_ref().map(|bar| bar.progress_bar.tick());
        });
    }

    #[inline]
    fn stop(self: Arc<ProgressIndicators>) {
        self.indicators.lock().unwrap().clear().unwrap();
    }

    /// Returns false if an error occurs
    #[inline]
    fn println(
        self: &Arc<ProgressIndicators>,
        message: &str
    ) -> bool {
        return match (self.indicators.lock().unwrap().println(message)) {
            Err(err) => {
                *(self.error_string.lock().unwrap()) = Some(err.to_string());
                false
            },
            Ok(()) => true
        };
    }

    #[inline]
    fn register_spinner(
        self: Arc<ProgressIndicators>,
        message: Option<Cow<'static, str>>,
        style_string: Option<&str>,
        tick_chars: Option<&str>,
        prefix: Option<Cow<'static, str>>,
    ) -> Arc<ProgressBar> {
        let style = indicatif::ProgressStyle::with_template(style_string.unwrap_or("{spinner} {wide_msg}"))
            .unwrap()
            .tick_chars(tick_chars.unwrap_or("⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"));
        let pb = indicatif::ProgressBar::new(1)
            .with_style(style);
        let pb = self.indicators.lock().unwrap().add(pb);

        if let Some(prefix) = prefix {
            pb.set_prefix(prefix);
        }
        if let Some(message) = message {
            pb.set_message(message);
        }

        let mut bars = self.progress_bars.lock().unwrap();
        let available_idx = bars.iter().enumerate().find_map(|(idx, el)| {
            if el.is_none() {
                Some(idx)
            } else {
                None
            }
        });
        let idx = available_idx.unwrap_or_else(|| {
            let idx = bars.len();
            bars.push(None);
            idx
        });

        let pb = Arc::new(ProgressBar {
            idx: idx,
            progress_bar: pb,
            indicators: self.clone(),
        });
        bars[idx] = Some(pb.clone());

        return pb;
    }
}

impl ProgressBar {
    #[inline]
    fn set_message(
        self: Arc<ProgressBar>,
        message: Cow<'static, str>
    ) {
        self.progress_bar.set_message(message);
    }

    #[inline]
    fn message(self: Arc<ProgressBar>) -> String {
        self.progress_bar.message()
    }

    #[inline]
    fn finish(
        self: Arc<ProgressBar>,
        message: Option<Cow<'static, str>>,
    ) {
        self.indicators.progress_bars.lock().unwrap()[self.idx] = None;
        if let Some(message) = message {
            self.progress_bar.finish_with_message(message);
        } else {
            self.progress_bar.finish_and_clear();
        }
    }
}

////// C API //////

//// ProgressIndicators ////

#[no_mangle]
pub unsafe extern "C" fn indicators_start(stream: Stream) -> *const ProgressIndicators {
    let indicators = ProgressIndicators::start(stream);
    return Arc::into_raw(indicators);
}

#[no_mangle]
pub unsafe extern "C" fn indicators_stop(indicators: *const ProgressIndicators) {
    let indicators = Arc::from_raw(indicators);
    indicators.stop();
}

#[no_mangle]
pub unsafe extern "C" fn indicators_tick(indicators: *const ProgressIndicators) {
    Arc::increment_strong_count(indicators);
    let indicators = Arc::from_raw(indicators);
    indicators.tick();
}

#[no_mangle]
pub unsafe extern "C" fn indicators_println(indicators: *const ProgressIndicators, message: *const ffi::c_char) {
    let message = CStr::from_ptr(message);
    Arc::increment_strong_count(indicators);
    let indicators = Arc::from_raw(indicators);
    indicators.println(message.to_str().unwrap());
}

#[no_mangle]
pub unsafe extern "C" fn indicators_register_spinner(
    indicators: *const ProgressIndicators,
    message: *const ffi::c_char,
    style_string: *const ffi::c_char,
    tick_chars: *const ffi::c_char,
    prefix: *const ffi::c_char
) -> *const ProgressBar {
    Arc::increment_strong_count(indicators);
    let indicators = Arc::from_raw(indicators);
    let message = if message.is_null() { None } else { Some(CStr::from_ptr(message)) };
    let style_string = if style_string.is_null() { None } else { Some(CStr::from_ptr(style_string)) };
    let tick_chars = if tick_chars.is_null() { None } else { Some(CStr::from_ptr(tick_chars)) };
    let prefix = if prefix.is_null() { None } else { Some(CStr::from_ptr(prefix)) };
    let pb = indicators.register_spinner(
        message.map(|e| Cow::Owned(String::from(e.to_str().unwrap()))),
        style_string.map(|e| e.to_str().unwrap()),
        tick_chars.map(|e| e.to_str().unwrap()),
        prefix.map(|e| Cow::Owned(String::from(e.to_str().unwrap()))),
    );
    return Arc::into_raw(pb);
}

#[no_mangle]
pub unsafe extern "C" fn progress_bar_set_message(pb: *const ProgressBar, message: *const ffi::c_char) {
    Arc::increment_strong_count(pb);
    let pb = Arc::from_raw(pb);
    if message.is_null() {
        panic!("Found NULL for message in `progress_bar_set_message`");
    }
    let message = CStr::from_ptr(message);
    pb.set_message(Cow::Owned(String::from(message.to_str().unwrap())));
}

#[no_mangle]
pub unsafe extern "C" fn progress_bar_message(pb: *const ProgressBar) -> *mut ffi::c_char {
    Arc::increment_strong_count(pb);
    let pb = Arc::from_raw(pb);
    CString::new(pb.message()).unwrap().into_raw()
}

#[no_mangle]
pub unsafe extern "C" fn progress_bar_finish(pb: *const ProgressBar, message: *const ffi::c_char) {
    let pb = Arc::from_raw(pb);
    let message = if message.is_null() { None } else { Some(CStr::from_ptr(message)) };
    pb.finish(message.map(|e| Cow::Owned(String::from(e.to_str().unwrap()))));
}

#[no_mangle]
pub unsafe extern "C" fn rs_cstring_destroy(ptr: *mut ffi::c_char) {
    _ = CString::from_raw(ptr);
}

// pub struct Progress {
//     progress: Mutex<indicatif::MultiProgress>,
//     enable_color: bool,
//     error_string: Mutex<Option<String>>,
//     progress_bars: Mutex<Vec<Option<Arc<indicatif::ProgressBar>>>>,
// }

// impl Progress {
//     fn remove_progress_bar(&self, idx: usize) {
//         self.progress_bars.lock().unwrap()[idx] = None;
//     }
// }

// pub struct ProgressBar {
//     idx: usize,
//     progress_bar: Arc<indicatif::ProgressBar>,
//     progress: Arc<Progress>,
// }

// #[no_mangle]
// pub unsafe extern "C" fn progress_is_color_enabled(prog: *const Progress) -> bool {
//     return ManuallyDrop::new(Arc::from_raw(prog)).enable_color;
// }

// #[no_mangle]
// pub unsafe extern "C" fn start_progress(stream: Stream) -> *const Progress {
//     let prog = indicatif::MultiProgress::new();
//     let term = match stream {
//         Stream::Stdout => {
//             prog.set_draw_target(indicatif::ProgressDrawTarget::stdout());
//             console::Term::stdout()
//         },
//         Stream::Stderr => {
//             prog.set_draw_target(indicatif::ProgressDrawTarget::stderr());
//             console::Term::stderr()
//         }
//     };
//     let term_features = term.features();
//     let enable_color = term_features.is_attended() && term_features.colors_supported();

//     let prog = Arc::new(Progress {
//         progress: Mutex::new(prog),
//         enable_color,
//         error_string: Mutex::new(None),
//         progress_bars: Mutex::new(Vec::new())
//     });
//     let ptr = Arc::into_raw(prog);
//     return ptr;
// }

// #[no_mangle]
// pub unsafe extern "C" fn tick_progress(progress: *const Progress) {
//     ManuallyDrop::new(Arc::from_raw(progress)).progress_bars.lock().unwrap().iter().for_each(|bar| {
//         bar.as_ref().map(|bar: &Arc<indicatif::ProgressBar>| bar.tick());
//     });
// }

// #[no_mangle]
// pub unsafe extern "C" fn stop_progress(prog: *const Progress) {
//     Arc::decrement_strong_count(prog);
//     let prog = Arc::from_raw(prog);
//     prog.progress.lock().unwrap().clear().unwrap();
// }

// #[no_mangle]
// pub unsafe extern "C" fn register_spinner(
//     prog: *const Progress,
//     message: *const ffi::c_char,
//     style_string: *const ffi::c_char,
//     tick_chars: *const ffi::c_char,
//     prefix: *const ffi::c_char
// ) -> *const ProgressBar {
//     let msg_str = if !message.is_null() { CStr::from_ptr(message).to_str().unwrap() } else { "" };
//     let style_str = if !style_string.is_null() { CStr::from_ptr(style_string).to_str().unwrap() } else { "{spinner} {wide_msg}" };
//     let tick_chars_str = if !tick_chars.is_null() { CStr::from_ptr(tick_chars).to_str().unwrap() } else { "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏" };
//     let prefix_str = if !prefix.is_null() { CStr::from_ptr(prefix).to_str().unwrap() } else { "" };

//     Arc::increment_strong_count(prog);
//     let prog = Arc::from_raw(prog);

//     let style = indicatif::ProgressStyle::with_template(style_str)
//         .unwrap()
//         .tick_chars(tick_chars_str);
//     let pb = indicatif::ProgressBar::new(1)
//         .with_style(style)
//         .with_prefix(prefix_str)
//         .with_message(msg_str);
//     let pb: indicatif::ProgressBar = prog.progress.lock().unwrap().add(pb);

//     let pb = Arc::new(pb);
//     let mut bars = prog.progress_bars.lock().unwrap();
//     let idx = bars.len(); // TODO: find None
//     bars.push(Some(pb.clone()));
//     let pb = Box::new(ProgressBar { idx, progress_bar: pb, progress: prog.clone() });
//     return Box::into_raw(pb);
// }

// #[no_mangle]
// pub unsafe extern "C" fn spinner_set_message(
//     spinner: *mut ProgressBar,
//     message: *const ffi::c_char
// ) {
//     let message_str = CStr::from_ptr(message).to_str().unwrap();
//     let pb = ManuallyDrop::new(Box::from_raw(spinner));
//     pb.progress_bar.set_message(message_str);
// }

// #[no_mangle]
// pub unsafe extern "C" fn finish_spinner(
//     spinner: *mut ProgressBar,
//     message: *const ffi::c_char
// ) {
//     let pb: Box<ProgressBar> = Box::from_raw(spinner);
//     pb.progress.remove_progress_bar(pb.idx);
//     if message.is_null() {
//         pb.progress_bar.finish();
//     } else {
//         let msg = CStr::from_ptr(message).to_str().unwrap();
//         pb.progress_bar.finish_with_message(msg);
//     }
// }

// /// Returns false if an error occurred
// #[no_mangle]
// pub unsafe extern "C" fn progress_println(
//     prog: *const Progress,
//     message: *const ffi::c_char
// ) -> bool {
//     Arc::increment_strong_count(prog);
//     let prog = Arc::from_raw(prog);
//     let message_str = CStr::from_ptr(message).to_str().unwrap();

//     return match (prog.progress.lock().unwrap().println(message_str)) {
//         Err(err) => {
//             *(prog.error_string.lock().unwrap()) = Some(err.to_string());
//             false
//         },
//         Ok(()) => true
//     };
// }
