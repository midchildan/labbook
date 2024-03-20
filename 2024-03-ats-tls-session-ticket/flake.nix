{
  description = "Test env for Apache Traffic Server with TLS session tickets";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.devenv.flakeModule ];

      systems = [
        "aarch64-linux"
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem = { lib, system, ... }: {
        devenv.shells = {
          default = import ./devenv.nix;

          openssl_1_1 = { lib, pkgs, ... }:
            let
              trafficserver' = pkgs.trafficserver.override {
                openssl = pkgs.openssl_1_1;
              };
              trafficserver = pkgs.enableDebugging trafficserver';
            in
            {
              imports = [ ./devenv.nix ];

              labbook.ports = {
                http = 9080;
                https = 9443;
              };

              services = {
                httpbin.enable = lib.mkForce false;
                trafficserver.package = lib.mkForce trafficserver;
              };
            };
        };

        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowInsecurePredicate = p:
            let
              isOpenSSL = p.pname == "openssl";
              isMatchingVersion = lib.versions.majorMinor p.version == "1.1";
            in
            isOpenSSL && isMatchingVersion;
        };
      };
    };
}
