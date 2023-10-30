{
  description = "Bring glibc 2.17 to nixpkgs-unstable";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;

      supportedSystems = [ "x86_64-linux" ];
      glibcVersion = "2.17";
      glibcSuffix = "_" + builtins.replaceStrings [ "." ] [ "_" ] glibcVersion;

      replaceStdenv = { pkgs, ... }:
        let
          glibcPackages = pkgs.callPackage ./packages/glibc { };
          glibc = glibcPackages."glibc${glibcSuffix}";

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
          stdenv = stdenvWith {
            cc = pkgs.stdenv.cc.cc.override { stdenv = bootstrapStdenv; };
            inherit (pkgs.stdenv.cc) bintools;
          };
        in
        stdenv;

      overlay = final: prev:
        let
          glibcPackages = prev.callPackage ./packages/glibc {
            inherit (prev) glibc glibcLocales glibcLocalesUtf8;
          };
        in
        {
          glibcLocales = glibcPackages."glibcLocales${glibcSuffix}";
          glibcLocalesUtf8 = glibcPackages."glibcLocalesUtf8${glibcSuffix}";
        };

      forAllSystems = f: lib.genAttrs supportedSystems (system:
        let
          isLinux = lib.hasSuffix "-linux" system;
          useCustomLibc = isLinux && (glibcVersion != null);
          pkgs = import nixpkgs {
            inherit system;
            config = lib.optionalAttrs useCustomLibc { inherit replaceStdenv; };
            overlays = lib.optionals useCustomLibc [ overlay ];
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
      // derivationsOnly (pkgs.callPackage ./packages/glibc { }));

      apps = forAllSystems (system: pkgs: {
        default = mkApp (pkgs.writeShellScript "show-symbol" ''
          set -euxo pipefail
          export PATH=${lib.makeBinPath (with pkgs; [ binutils gnugrep ])}
          nm ${pkgs.stdenv.cc.libc}/lib/libpthread.so.0 | grep pthread_atfork
        '');
      });
    };
}
