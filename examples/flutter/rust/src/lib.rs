use std::sync::atomic::{AtomicU64, Ordering};

static COUNT: AtomicU64 = AtomicU64::new(0);

#[unsafe(no_mangle)]
pub extern "C" fn reset_count() {
    COUNT.store(0, Ordering::SeqCst);
}

#[unsafe(no_mangle)]
pub extern "C" fn increase_count() {
    COUNT.fetch_add(1, Ordering::SeqCst);
}

#[unsafe(no_mangle)]
pub extern "C" fn get_count() -> u64 {
    COUNT.load(Ordering::SeqCst)
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_counter() {
        crate::reset_count();
        assert_eq!(crate::get_count(), 0);

        crate::increase_count();
        assert_eq!(crate::get_count(), 1);

        crate::increase_count();
        crate::increase_count();
        assert_eq!(crate::get_count(), 3);

        crate::reset_count();
        assert_eq!(crate::get_count(), 0);
    }
}
