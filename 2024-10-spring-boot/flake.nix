{
  description = "Spring Boot Playground";

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
    inputs@{ parts, devenv-root, ... }:
    parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devenv.flakeModule
        inputs.treefmt.flakeModule
      ];
      systems = [
        "x86_64-linux"
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
          q = lib.escapeShellArg;
          qs = lib.escapeShellArgs;

          devenvCfg = config.devenv.shells.default;
          gradlew = "${devenvCfg.env.DEVENV_ROOT}/gradlew";

          jdt-language-server =
            pkgs.runCommand pkgs.jdt-language-server.name
              {
                nativeBuildInputs = [ pkgs.makeWrapper ];
              }
              ''
                mkdir -p $out/bin
                makeWrapper ${pkgs.jdt-language-server}/bin/jdtls $out/bin/jdtls \
                  --add-flags -javaagent:${q pkgs.lombok}/share/java/lombok.jar
              '';
        in
        {
          devenv.shells.default = {
            name = "Spring Boot Playground";

            devenv.root =
              let
                devenvRootFileContent = builtins.readFile devenv-root.outPath;
              in
              lib.mkIf (devenvRootFileContent != "") devenvRootFileContent;

            packages = [ jdt-language-server ] ++ config.treefmt.build.devShell.nativeBuildInputs;

            languages.java = {
              enable = true;
              jdk.package = pkgs.jdk21;
              gradle.enable = true;
            };

            processes = {
              build.exec = qs [
                gradlew
                "build"
                "--continuous"
              ];

              serve.exec = ''
                exec ${
                  qs [
                    gradlew
                    "bootRun"
                  ]
                } "$@"
              '';
            };

            stdenv = pkgs.stdenvNoCC;
            containers = lib.mkIf pkgs.stdenv.isDarwin (lib.mkForce { });
          };

          treefmt = {
            projectRootFile = "flake.nix";
            settings.excludes = [ "*.lock" ];
            programs = {
              google-java-format.enable = true;
              nixfmt.enable = true;
            };
          };
        };
    };
}
