#[test]
fn cmake() {
    let dir = super::example_dir("cmake");
    let mut output = String::new();
    let (mut iter, code) = crate::run(&dir, &mut output);

    assert_eq!(code, Some(0));
    assert_eq!(iter.next(), Some("Tests passed successfully!"));
    assert_eq!(iter.next(), None);
}
