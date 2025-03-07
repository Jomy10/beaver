#[test]
fn pre_phase_hooks() {
    let dir = super::example_dir("pre-phase-hooks");
    let mut out = String::new();
    let (mut iter, code) = crate::run(&dir, &mut out);

    assert_eq!(code, Some(0));
    assert_eq!(iter.next(), Some("I AM GENERATED"));
    assert_eq!(iter.next(), None);
}
