{
  description = "Bring glibc 2.17 to nixpkgs-unstable";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-glibc-2-17 = {
      url = "github:NixOS/nixpkgs/fd7bc4ebfd0bd86a86606cbc4ee22fbab44c5515";
      flake = false;
    };
    nixpkgs-glibc-2-24 = {
      url = "github:NixOS/nixpkgs/0ff2179e0ffc5aded75168cb5a13ca1821bdcd24";
      flake = false;
    };
    nixpkgs-glibc-2-25 = {
      url = "github:NixOS/nixpkgs/09d02f72f6dc9201fbfce631cb1155d295350176";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;

      supportedSystems = [ "x86_64-linux" ];
      libcSuffix = "2_17";

      replaceStdenv = { pkgs, ... }:
        let
          glibcPackages = pkgs.callPackage ./packages/glibc inputs;
          glibc = glibcPackages."glibc_${libcSuffix}";

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
        stdenv;

      overlays = final: prev:
        let
          glibcPackages = prev.callPackage ./packages/glibc (inputs // {
            inherit (prev) glibc glibcLocales glibcLocalesUtf8;
          });
        in
        {
          glibcLocales = glibcPackages."glibcLocales_${libcSuffix}";
          glibcLocalesUtf8 = glibcPackages."glibcLocalesUtf8_${libcSuffix}";
        };

      forAllSystems = f: lib.genAttrs supportedSystems (system:
        let
          isLinux = lib.hasSuffix "-linux" system;
          useCustomLibc = isLinux && (libcSuffix != null);
          pkgs = import nixpkgs {
            inherit system;
            config = lib.optionalAttrs useCustomLibc { inherit replaceStdenv; };
            overlays = lib.optionals useCustomLibc [ overlays ];
          };
        in
        f system pkgs);

      mkApp = program: {
        type = "app";
        program = toString program;
      };

      derivationsOnly = lib.filterAttrs (_: v: lib.isDerivation v);
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
      }
      // derivationsOnly (pkgs.callPackage ./packages/glibc inputs));

      apps = forAllSystems (system: pkgs: {
        default = mkApp (pkgs.writeShellScript "show-symbol" ''
          set -euxo pipefail
          export PATH=${lib.makeBinPath (with pkgs; [ binutils gnugrep ])}
          nm ${pkgs.stdenv.cc.libc}/lib/libpthread.so.0 | grep pthread_atfork
        '');
      });
    };
}
