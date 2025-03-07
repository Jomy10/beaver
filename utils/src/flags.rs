pub fn concat_quoted(flags: impl Iterator<Item = String>) -> String {
    flags.into_iter().map(|flag| format!("\"{flag}\"")).fold(String::new(), |acc, str| {
        let mut acc = acc;
        acc.push_str(&str);
        acc.push(' ');
        acc
    })
}
