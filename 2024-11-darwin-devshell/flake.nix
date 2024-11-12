{
  description = "Demonstration of apple_sdk's setup hook breaking /usr/bin/git";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    treefmt = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };
  };

  outputs =
    inputs@{ devenv-root, ... }:
    inputs.parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.devenv.flakeModule ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        {
          lib,
          config,
          pkgs,
          ...
        }:
        let
          stdenvFixed = pkgs.stdenvAdapters.overrideInStdenv pkgs.stdenvNoCC [
            (pkgs.makeSetupHook { name = "unset-apple-sdk-vars"; } (
              pkgs.writeShellScript "unset-apple-sdk-vars.sh" ''
                unset DEVELOPER_DIR SDKROOT
              ''
            ))
          ];
        in
        {
          devenv.shells = rec {
            default = {
              name = lib.mkDefault "darwin-devshell-broken";

              enterShell = ''
                printf '%s=%s\n' DEVELOPER_DIR "$DEVELOPER_DIR" SDKROOT "$SDKROOT"
              '';

              stdenv = lib.mkDefault pkgs.stdenvNoCC;
            };

            fixed = {
              name = "darwin-devshell-fixed";
              imports = [ default ];
              stdenv = stdenvFixed;
            };

            still-broken = {
              name = "darwin-devshell-still-broken";
              imports = [ default ];

              # Doesn't work because these env vars are set in a setup hook, which runs after env vars
              # are initialized from derivation attributes.
              env = {
                DEVELOPER_DIR = "";
                SDKROOT = "";
              };
            };

            pre-commit = {
              name = "darwin-devshell-pre-commit";

              # This runs too late.
              enterShell = ''
                export DEVELOPER_DIR="" SDKROOT=""
              '';

              tasks."playground:clean-previous" = {
                before = [ "devenv:git-hooks:install" ];
                exec = ''
                  cfgFile=${lib.escapeShellArg config.devenv.shells.pre-commit.env.DEVENV_ROOT}/../.pre-commit-config.yaml
                  if [[ -L "$cfgFile" ]]; then
                    rm "$cfgFile"
                  fi
                '';
              };

              pre-commit.hooks.example = {
                enable = true;
                entry = "echo success";
                pass_filenames = false;
              };

              stdenv = lib.mkDefault pkgs.stdenvNoCC;
            };

            pre-commit-fixed = {
              name = "darwin-devshell-pre-commit-fixed";
              imports = [ pre-commit ];
              stdenv = stdenvFixed;
            };
          };

          formatter = pkgs.nixfmt-rfc-style;
        };
    };
}
