#[test]
fn dependencies() {
    let dir = super::example_dir("dependencies");
    let mut output = String::new();
    let (mut iter, code) = crate::run(&dir, &mut output);

    assert_eq!(code, Some(0));
    assert_eq!(iter.next(), Some("1 + 2 = 3"));
    assert_eq!(iter.next(), Some("uuid_is_null = 1"));
    assert_eq!(iter.next(), None);
}
