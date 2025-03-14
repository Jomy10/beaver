#[test]
fn swift() {
    let dir = super::example_dir("cargo");
    let mut stdout = String::new();
    let (mut iter, code) = crate::run(&dir, &mut stdout);

    assert_eq!(code, Some(0));
    assert!(iter.next().unwrap().starts_with("Hello "));
    assert_eq!(iter.next(), None);
}
