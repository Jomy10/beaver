use std::cell::RefCell;
use std::collections::LinkedList;
use std::ops::Deref;
use std::path::Path;
use std::sync::{self, Arc, OnceLock, mpsc};
use std::thread::ThreadId;

use beaver::Beaver;
use log::*;

use crate::{ruby_lib, BeaverRubyError};

pub struct BeaverRubyContext<'a> {
    pub context: sync::Weak<Beaver>,
    #[allow(unused)]
    cleanup: magnus::embed::Cleanup,
    pub(crate) args: RefCell<LinkedList<String>>,
    #[allow(unused)]
    pub(crate) thread_handle: std::thread::JoinHandle<()>,
    pub(crate) thread_id: std::thread::ThreadId,
    pub(crate) sender: Arc<RubyThreadSender<'a>>,
}

// We make sure non-sendable variables are always accessed from the ruby thread
unsafe impl<'a> Send for BeaverRubyContext<'a> {}
unsafe impl<'a> Sync for BeaverRubyContext<'a> {}

impl<'a> std::fmt::Debug for BeaverRubyContext<'a> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("BeaverRubyContext { ... }")
    }
}

impl<'a> BeaverRubyContext<'a> {
    /// Are there any arguments left?
    pub fn has_args(&self) -> bool {
        self.args.borrow().len() > 0
    }

    pub fn args<'b>(&'b self) -> impl Deref<Target = LinkedList<String>> + 'b {
        self.args.borrow()
    }

    pub fn block_execute_on(&self, worker: RubyThreadWorker<'a>) -> Result<(), BeaverRubyError> {
        if self.thread_id == std::thread::current().id() {
            worker()
        } else {
            block_execute_on(&self.sender, worker)
        }
    }

    pub fn async_execute_on(&self, worker: RubyThreadWorker<'a>) {
        if self.thread_id == std::thread::current().id() {
            worker().unwrap();
        } else {
            async_execute_on(&self.sender, worker)
        }
    }

    pub fn context(&self) -> Arc<Beaver> {
        self.context.upgrade().expect("Beaver dropped before ruby")
    }
}

impl<'a> Drop for BeaverRubyContext<'a> {
    fn drop(&mut self) {
        // if Arc::strong_count(&self.context) != 1 {
        //     panic!("Beaver outlives ruby context")
        // }
    }
}

// /// Used to access context from ruby
// pub(crate) static mut RBCONTEXT: MaybeUninit<Arc<Beaver>> = MaybeUninit::uninit();
/// Used in BeaverRubyError to ensure a Ruby value doesn't outlive BeaverRubyContext
pub(crate) static CTX: OnceLock<Arc<BeaverRubyContext<'static>>> = OnceLock::new();

/// This function should ONLY be called at the end of the program.
/// This deallocates the beaver context that beaver uses. If it can't
/// use it anymore, the program will crash
// pub unsafe fn cleanup() {
//     let ctx = Arc::into_raw(CTX.get().unwrap().clone());
//     unsafe { Arc::decrement_strong_count(ctx) };
//     let ctx = unsafe { Arc::from_raw(ctx) };
//     drop(ctx);
// }

pub type RubyThreadWorker<'a> = Box<dyn FnOnce() -> Result<(), BeaverRubyError> + Send + 'a>;
pub(crate) type RubyThreadSender<'a> = mpsc::Sender<(RubyThreadWorker<'a>, Option<mpsc::Sender<Result<(), BeaverRubyError>>>)>;

/// Block until the work is done on the specific thread
pub(crate) fn block_execute_on<'a>(sender: &RubyThreadSender<'a>, worker: RubyThreadWorker<'a>) -> Result<(), BeaverRubyError> {
    let (tx, rx) = mpsc::channel::<Result<(), BeaverRubyError>>();

    sender.send((worker, Some(tx))).unwrap();

    return rx.recv().unwrap();
}

pub(crate) fn async_execute_on<'a>(sender: &RubyThreadSender<'a>, worker: RubyThreadWorker<'a>) {
    sender.send((worker, None)).unwrap()
}

/// This function is not thread safe and should only be called once
pub unsafe fn execute_script<P: AsRef<Path>>(script_file: P, args: LinkedList<String>, context: &sync::Weak<Beaver>) -> crate::Result<Arc<BeaverRubyContext<'static>>> {
    let (tx, rx) = mpsc::channel::<(RubyThreadWorker, Option<mpsc::Sender<Result<(), BeaverRubyError>>>)>();

    let (thread_tx, thread_rx) = mpsc::channel::<ThreadId>();
    let ruby_thread = std::thread::spawn(move || {
        thread_tx.send(std::thread::current().id()).unwrap();
        loop {
            match rx.recv() {
                Ok((task, done)) => {
                    let res = task();
                    if let Some(done) = done {
                        done.send(res).unwrap();
                    } else {
                        if let Err(err) = res {
                            error!("{}", err);
                        }
                    }
                },
                Err(_) => {
                    break;
                }
            }
        }
    });

    let tx = Arc::new(tx);
    let context = context.clone();
    let ruby_thread_id = thread_rx.recv().unwrap();
    let script_file = script_file.as_ref().to_owned();
    block_execute_on(&tx.clone(), Box::new(move || {
        let cleanup = unsafe { magnus::embed::init() };
        let ruby = magnus::Ruby::get()?;

        // By constructing this, we assure that `context` and `cleanup` live equally long. `context`
        // uses ruby and ruby uses `context`
        CTX.set(Arc::new(BeaverRubyContext {
            context,
            cleanup,
            args: RefCell::new(args),
            thread_handle: ruby_thread,
            thread_id: ruby_thread_id,
            sender: tx,
        })).unwrap();

        ruby.script(script_file.file_name().map_or("beaver", |str| str.to_str().unwrap_or("beaver")));

        ruby_lib::register(&ruby)?;

        ruby.require(std::path::absolute(script_file)?)?;

        Ok(())
    }))?;

    return Ok(CTX.get().unwrap().clone());
}
