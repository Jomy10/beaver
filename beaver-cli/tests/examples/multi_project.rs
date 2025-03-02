#[test]
pub fn multi_project() {
    let dir = super::example_dir("multi-project");
    let mut out = String::new();
    let (mut iter, code) = crate::run(&dir, &mut out);

    assert_eq!(code, Some(0));
    assert_eq!(iter.next(), Some("cmp = 0"));
    assert_eq!(iter.next(), Some("buffer = [INFO] Hello world"));
    assert_eq!(iter.next(), None);
}
