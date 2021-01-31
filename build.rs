// build.rs

//use std::process::Command;
use std::env;
use std::fs;
use std::path::Path;
use quale::which;

fn main() {
    let out_dir = env::var("OUT_DIR").unwrap();
    let dest_path = Path::new(&out_dir).join("config.rs");
    let sh = which("sh").unwrap();

    fs::write(
        &dest_path,
        format!("static BIN_SH_PATH: &str = {:?};", sh)
    ).unwrap();
}
