use std::env;
use std::io;
use shell_words;

const EXCLUDED_ENVS: &'static [&'static str] = &[
    "_",
    "CONCC_DEBUG_DISPATCH",
    "CONCC_DEBUG_SCRIPTIFY",
    "CONCC_DEBUG_SSHFS",
    "CONCC_DIR",
    "CONCC_RUN_LOCALLY",
    "HOSTNAME",
    "OLDPWD",
    "PWD",
];

fn main() -> io::Result<()> {
    let debug = match env::var("CONCC_DEBUG_SCRIPTIFY") {
        Ok(v) if v == "1" => true,
        _ => false,
    };

    let mut script = vec![];

    if debug {
        script.push("set -x".to_string());
    }

    script.push(r#"SCRIPT_FILE="$0""#.to_string());
    script.push(r#"trap "rm $SCRIPT_FILE" EXIT INT TERM"#.to_string());

    script.push(format!("cd {}", env::current_dir()?.to_str().unwrap()));

    for (k, v) in env::vars() {
        if EXCLUDED_ENVS.contains(&k.as_str()) {
            continue;
        }
        script.push(format!("export {}={}", k, shell_words::quote(&v)));
    }

    script.push(shell_words::join(env::args().skip(1)));

    println!("{}", script.join("\n"));

    Ok(())
}
