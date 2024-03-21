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

          openssl_1_1 = { lib, config, pkgs, ... }:
            let
              trafficserver' = pkgs.trafficserver.override {
                openssl = pkgs.openssl_1_1;
              };
              trafficserver = pkgs.enableDebugging trafficserver';
            in
            {
              imports = [ ./devenv.nix ];

              devenv.dotfile = "${config.devenv.root}/.devenv-openssl_1_1";

              playground.ports = {
                http = 7080;
                https = 7443;
              };

              services = {
                httpbin.enable = lib.mkForce false;
                trafficserver.package = lib.mkForce trafficserver;
              };

              process-managers.process-compose.settings.port = 7999;
            };

          legacy-api = { lib, config, pkgs, ... }:
            let
              trafficserver' = pkgs.trafficserver.overrideAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
                  pkgs.autoreconfHook
                ] ++ lib.optionals pkgs.stdenv.isDarwin [
                  (pkgs.writeShellScriptBin "xcrun" ''
                    echo "[WARN] Skipping '$@'"
                  '')
                ];
                postPatch = ''
                  find . -type f -name '*.txt' -exec \
                    sed -i -e 's/HAVE_SSL_CTX_SET_TLSEXT_TICKET_KEY_EVP_CB/PG_UNDEFINED/g' {} +
                '';
              });
              trafficserver = pkgs.enableDebugging trafficserver';
            in
            {
              imports = [ ./devenv.nix ];

              devenv.dotfile = "${config.devenv.root}/.devenv-legacy-api";

              playground.ports = {
                http = 6080;
                https = 6443;
              };

              services = {
                httpbin.enable = lib.mkForce false;
                trafficserver.package = lib.mkForce trafficserver;
              };

              process-managers.process-compose.settings.port = 6999;
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
