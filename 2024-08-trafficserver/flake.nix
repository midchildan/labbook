{
  description = "Traffic Server";

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
        { lib, config, ... }:
        {
          devenv.shells.default =
            let
              ports = {
                ats = "8080";
                httpbin = "8081";
              };
            in
            {
              devenv.root =
                let
                  devenvRootFileContent = builtins.readFile devenv-root.outPath;
                in
                lib.mkIf (devenvRootFileContent != "") devenvRootFileContent;

              name = "trafficserver";

              packages = config.treefmt.build.devShell.nativeBuildInputs;

              services.trafficserver = {
                enable = true;
                remap = "map / http://127.0.0.1:${ports.httpbin}";
                records.proxy.config = {
                  http = {
                    server_ports = "${ports.ats} ${ports.ats}:ipv6";
                    cache.required_headers = 0;
                    insert_response_via_str = 4;
                  };
                  admin.user_id = "#-1";
                };
              };

              services.httpbin = {
                enable = true;
                bind = [ "127.0.0.1:${ports.httpbin}" ];
                extraArgs = [
                  "--access-logfile"
                  "-"
                ];
              };
            };

          treefmt = {
            projectRootFile = "flake.nix";
            settings.excludes = [ "*.lock" ];
            programs.nixfmt.enable = true;
          };
        };
    };
}
