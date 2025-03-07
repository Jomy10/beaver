use crate::run;

#[test]
fn cmake() {
    let dir = super::example_dir("cmake");
    let mut stdout = String::new();
    let (mut iter, code) = run(&dir, &mut stdout);

    assert_eq!(code, Some(0));
    assert_eq!(iter.next(), Some("Tests passed successfully!"));
    assert_eq!(iter.next(), None);
}
