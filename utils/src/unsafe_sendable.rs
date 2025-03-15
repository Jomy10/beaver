/// Send a value between threads which does not implement Send
pub struct UnsafeSendable<T>(T);

impl<T> UnsafeSendable<T> {
    pub fn new(t: T) -> UnsafeSendable<T> {
        UnsafeSendable(t)
    }
}

impl<T> UnsafeSendable<T> {
    pub unsafe fn value(&self) -> &T {
        &self.0
    }
}

unsafe impl<T> Send for UnsafeSendable<T> {}
unsafe impl<T> Sync for UnsafeSendable<T> {}
