unsafe extern "C" {
    fn c_add(a: i32, b: i32) -> i32;
}

#[unsafe(no_mangle)]
pub extern "C" fn rust_add(a: i32, b: i32) -> i32 {
    unsafe { c_add(a, b) }
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_rust_add() {
        assert_eq!(crate::rust_add(1, 1), 2);
    }
}
