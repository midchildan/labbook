{
  description = "Athenz with Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # required for Devenv
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devenv.flakeModule
        inputs.treefmt-nix.flakeModule
        ../common/flake-parts/callpackages.nix
      ];

      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      perSystem =
        {
          lib,
          config,
          pkgs,
          self',
          ...
        }:
        let
          devenvRootFileContent = builtins.readFile inputs.devenv-root.outPath;
          listEntries = dir: map (name: "${dir}/${name}") (builtins.attrNames (builtins.readDir dir));
          zms = self'.packages.athenz-zms;
        in
        {
          callPackages = {
            enable = true;
            directory = ./packages;
          };

          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
          };

          devenv.shells.default = {
            name = "athenz";

            imports = listEntries ./devenv;

            devenv.root = lib.mkIf (devenvRootFileContent != "") devenvRootFileContent;

            packages = [ self'.packages.athenz-utils ];

            services.athenz-zms = {
              enable = true;
              package = self'.packages.athenz-zms;
            };

            services.athenz-zts = {
              enable = true;
              package = self'.packages.athenz-zts;
            };

            services.mysql.settings.mysqld.port = 3306;
          };
        };
    };
}
