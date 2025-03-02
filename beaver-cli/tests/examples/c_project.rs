use crate::run;

#[test]
fn c_project() {
    let dir = super::example_dir("c-project");
    let mut stdout = String::new();
    let (mut iter, code) = run(&dir, &mut stdout);

    assert_eq!(code, Some(0));
    assert_eq!(iter.next(), Some("Hello world!"));
    assert_eq!(iter.next(), None);
}
