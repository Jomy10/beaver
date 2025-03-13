#[test]
pub fn objc() {
    let dir = super::example_dir("multi-project");
    let mut out = String::new();
    let (_, code) = crate::run(&dir, &mut out);

    assert_eq!(code, Some(0));
}
