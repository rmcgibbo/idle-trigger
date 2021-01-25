{ pkgs ? import <nixpkgs> {}} :

pkgs.rustPlatform.buildRustPackage rec {
  name = "idle-trigger";
  cargoSha256 = "0h1vgbx4y72x7bwf842i5ibnqkwkxd2kv687y01lnzg45dhdm0az";
  src = let
    filterSrcByPrefix = src: prefixList:
      pkgs.lib.cleanSourceWith {
        filter = (path: type:
          let relPath = pkgs.lib.removePrefix (toString ./. + "/") (toString path);
          in pkgs.lib.any (prefix: pkgs.lib.hasPrefix prefix relPath) prefixList);
        inherit src;
      };
  in
    filterSrcByPrefix ./. [ "Cargo.toml" "Cargo.lock" "src" ];
}
