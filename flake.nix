{
  description = "Bring glibc 2.17 to nixpkgs-unstable";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-glibc-2_17 = {
      url = "github:NixOS/nixpkgs/fd7bc4ebfd0bd86a86606cbc4ee22fbab44c5515";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;

      supportedSystems = [ "x86_64-linux" ];

      replaceStdenv = { pkgs, ... }:
        let
          oldPkgs = import inputs.nixpkgs-glibc-2_17 { inherit (pkgs) system; };
          glibc-2_17 = oldPkgs.glibc;
          glibc = pkgs.callPackage ./packages/glibc {
            inherit glibc-2_17;
          };

          stdenvWith = { cc, bintools, libc ? glibc }:
            let
              wrappedCC = pkgs.wrapCCWith {
                inherit cc libc;
                bintools = bintools.override { inherit libc; };
              };
            in
            pkgs.overrideCC pkgs.stdenv wrappedCC;

          bootstrapStdenv = stdenvWith {
            inherit (pkgs.stdenv.cc) cc bintools;
          };

          # rebuild libstdc++
          cc = pkgs.stdenv.cc.cc.override { stdenv = bootstrapStdenv; };
          stdenv = stdenvWith {
            inherit cc;
            inherit (pkgs.stdenv.cc) bintools;
          };
        in
        # stdenv; # skip the rebuild for this flake since it doesn't use c++
        bootstrapStdenv;

      forAllSystems = f: lib.genAttrs supportedSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = { inherit replaceStdenv; };
          };
        in
        f system pkgs);

      mkApp = program: {
        type = "app";
        program = toString program;
      };
    in
    {
      packages = forAllSystems (system: pkgs: {
        default = pkgs.runCommandCC "link-pthread-atfork"
          {
            code = ''
              void pthread_atfork(void);
              int main(void) {
                pthread_atfork();
                return 0;
              }
            '';
            executable = true;
            passAsFile = [ "code" ];
          }
          ''
            n=$out/bin/$name
            mkdir -p "$(dirname "$n")"
            mv "$codePath" code.c
            $CC -pthread code.c -o "$n"
          '';
      });

      apps = forAllSystems (system: pkgs: {
        default = mkApp (pkgs.writeShellScript "show-symbol" ''
          set -euxo pipefail
          export PATH=${lib.makeBinPath (with pkgs; [ binutils gnugrep ])}
          nm ${pkgs.stdenv.cc.libc}/lib/libpthread.so.0 | grep pthread_atfork
        '');
      });
    };
}
