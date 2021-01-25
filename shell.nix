{ pkgs ? import <nixpkgs> {
    overlays = let
      rust_overlay = import (builtins.fetchTarball "https://github.com/oxalica/rust-overlay/archive/4c6a814f4b6ae89a9767bfcae4cbe2e49ca7c19e.tar.gz");
    in
      [
        rust_overlay
        (self: super:
            {
              rustc = self.latest.rustChannels.nightly.rust;
              cargo = self.latest.rustChannels.nightly.rust;
            }
        )
      ];
}} :
let
  rustChan = pkgs.rustChannelOf {
    date = "2021-01-24";
    channel = "nightly";
  };

  rust = rustChan.rust.override {
    extensions = [
        "clippy-preview"
        "rls-preview"
        "rustfmt-preview"
        "rust-analysis"
        "rust-std"
        "rust-src"
    ];
  };
in
pkgs.mkShell {
  buildInputs = [
    pkgs.cargo-fuzz
    pkgs.gitAndTools.git-extras
    pkgs.gitAndTools.pre-commit
    rust
  ];

  shellHook = ''
    export PATH=$PWD/target/debug:$PATH
  '';
}
