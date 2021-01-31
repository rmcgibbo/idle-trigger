{ pkgs ? import <nixpkgs> {}} :

pkgs.rustPlatform.buildRustPackage rec {
  name = "idle-trigger";
  cargoSha256 = "0s4162mxm2f1xra3p82w9vd82ihv7sfqwdpihb56d3y0fjw5381d";
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
