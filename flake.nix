{
  description = "TODO";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    utils.url = "github:numtide/flake-utils";
    naersk = {
      url = "github:nmattia/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-compat, utils, naersk }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        naersk-lib = pkgs.callPackage naersk { };
      in rec {
        packages.idle-trigger = naersk-lib.buildPackage {
          name = "idle-trigger";
          root = ./.;
        };
        defaultPackage = packages.idle-trigger;

        nixosModules.idle-trigger = { lib, pkgs, config, ... }:
          with lib;
          let cfg = config.services.idle-trigger;
          in {
            options.services.idle-trigger = {
              enable = mkEnableOption "Idle trigger service";
              measurementInterval = mkOption {
                type = types.str;
                default = "5 sec";
              };
              thresholdCpuPercent = mkOption {
                type = types.float;
                default = 5.0;
              };
              window = mkOption {
                type = types.str;
                default = "45 min";
              };
              cooldown = mkOption {
                type = types.str;
                default = "2 min";
              };
            };
            config = mkIf cfg.enable {
              systemd.services.idle-trigger = {
                enable = true;
                description = "Idle trigger";
                wantedBy = [ "multi-user.target" ];
                serviceConfig = let
                  config_toml = pkgs.writeText "config.toml" ''
                    # See https://github.com/rmcgibbo/idle-trigger/blob/master/README.md
                    measurement_interval = "${cfg.measurementInterval}"
                    threshold_cpu_percent = ${lib.strings.floatToString cfg.thresholdCpuPercent}
                    window = "${cfg.window}"
                    cooldown = "${cfg.cooldown}"
                    command = """
                      ${pkgs.awscli2}/bin/aws autoscaling terminate-instance-in-auto-scaling-group \
                      --instance-id $(${pkgs.curl}/bin/curl --connect-timeout 5 \
                        --max-time 10 \
                        --retry 5 \
                        --retry-delay 0 \
                        --retry-max-time 40 \
                        --silent \
                        http://169.254.169.254/latest/dynamic/instance-identity/document | ${pkgs.jq}/bin/jq .instanceId -r) \
                      --should-decrement-desired-capacity
                    """
                  '';
                in {
                  ExecStart =
                    "${defaultPackage}/bin/idle-trigger ${config_toml}";
                  Restart = "on-failure";
                  OOMScoreAdjust = -500;
                };
              };
            };
          };

      });
}
