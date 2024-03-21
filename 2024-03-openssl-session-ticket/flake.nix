{
  description = "TLS session tickets with OpenSSL";

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

      perSystem = { lib, system, pkgs, self', ... }: {
        packages = {
          server = pkgs.stdenv.mkDerivation {
            name = "tls-server";
            src = ./.;

            buildInputs = [ pkgs.openssl ];
            nativeBuildInputs = with pkgs; [ pkg-config clang-tools ];

            installFlags = [ "PREFIX=$(out)" ];

            meta.mainProgram = "server";
          };

          server-openssl_1_1 = self'.packages.server.overrideAttrs (_: {
            buildInputs = [ pkgs.openssl_1_1 ];
          });

          server-legacy-api = self'.packages.server.overrideAttrs (_: {
            CFLAGS = "-DLEGACY";
          });
        };

        devenv.shells.default = { lib, config, ... }:
          let
            ports = lib.mapAttrs (_: toString) {
              vanilla = 8443;
              openssl_1_1 = 7443;
              legacy = 6443;
            };

            keyVersion = "01";
            stek = [
              "^name..........$"
              "^aesKey${keyVersion}......$"
              "^hmacKey${keyVersion}.....$"
            ];
            stekFile = pkgs.writeText "stek.dat" (lib.concatStringsSep "" stek);

            cert = ../common/certs/localhost.crt;
            key = ../common/certs/localhost.key;
            session = "${config.env.DEVENV_ROOT}/session.pem";

            q = lib.escapeShellArg;
          in
          assert lib.all (key: lib.stringLength key == 16) stek;
          {
            packages = [ pkgs.openssl ];

            processes = {
              vanilla.exec = lib.escapeShellArgs [
                (lib.getExe self'.packages.server)
                ports.vanilla
                stekFile
                cert
                key
              ];
              openssl_1_1.exec = lib.escapeShellArgs [
                (lib.getExe self'.packages.server-openssl_1_1)
                ports.openssl_1_1
                stekFile
                cert
                key
              ];
              legacy-api.exec = lib.escapeShellArgs [
                (lib.getExe self'.packages.server-legacy-api)
                ports.legacy
                stekFile
                cert
                key
              ];
            };

            scripts = {
              client = {
                description = "Connect to the TLS server.";
                exec = ''
                  set -euo pipefail

                  main() {
                    local sess_flag
                    case "''${1:-}" in
                      connect) sess_flag=sess_out ;;
                      reconnect) sess_flag=sess_in ;;
                      *) usage ;;
                    esac

                    local port
                    case "''${2:-}" in
                      vanilla) port=${ports.vanilla} ;;
                      openssl_1_1) port=${ports.openssl_1_1} ;;
                      legacy) port=${ports.legacy} ;;
                      *) usage ;;
                    esac

                    set -x
                    ${lib.getExe pkgs.openssl} s_client \
                      -connect "localhost:$port" \
                      -servername localhost \
                      -"$sess_flag" ${q session} \
                      -CAfile ${cert}
                  }

                  usage() {
                    printf 'Usage: %s %s %s\n' \
                      "$0" '[connect|reconnect]' '[vanilla|openssl_1_1|legacy]'
                    exit 1
                  }

                  main "$@"
                '';

              };

              show = {
                description = "Show session ticket content.";
                exec = ''
                  set -x
                  ${lib.getExe pkgs.openssl} sess_id -in ${q session} -noout -text
                '';
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
