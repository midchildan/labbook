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

          # Rebuild GCC with the preferred libc to
          #  1. Change the built-in C standard include path
          #  2. Make libstdc++ binary compatible with the provided libc
          #
          # No. 1 might better be solved in Nixpkgs by making cc-wrapper add
          # the -nostddinc flag.
          stdenv' = stdenvWith {
            cc = pkgs.stdenv.cc.cc.override { stdenv = bootstrapStdenv; };
            inherit (pkgs.stdenv.cc) bintools;
          };

          # Some packages are forwarded from the bootstrapping phase of Nixpkgs,
          # bypassing normal overlays. stdenv.overrides is an overlay that'll
          # be applied regardless.
          stdenv = stdenv'.override {
            overrides = final: prev: {
              xz = prev.xz.override { stdenv = stdenv'; };
              inherit (pkgs)
                # The following packages can be forwarded from the original
                # package set because they're not used as libraries and won't
                # cause libc conflicts.
                bash binutils diffutils findutils gawk gnused gnutar gnugrep
                gnupatch patchelf
                # Remove infinite recursion with xz
                fetchurl;
            };
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
          util-linux = prev.util-linux.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ (with prev; [
              autoreconfHook
              pkg-config
              gtk-doc
            ]);
            patches = (old.patches or [ ]) ++ [
              # Fix build with older versions of libc
              (prev.fetchpatch {
                url = "https://github.com/util-linux/util-linux/commit/7d679f29aee9f56b07bd792e07b5b4e1ca2f3fa7.patch";
                sha256 = "sha256-0105v5yT8Q03+qdbyYgnp5+5rHJApTJhOLAM4qthplw=";
              })
            ];
          });
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

      derivationsOnly = lib.filterAttrs (_: lib.isDerivation);
    in
    {
      packages = forAllSystems (system: pkgs: {
        default = pkgs.runCommandCC "debug-build"
          {
            code = ''
              #include <inttypes.h>
              #include <stdio.h>
              int main(void) {
                uint64_t foo = 1;
                printf("%" PRIx64 "\n", foo);
                return 0;
              }
            '';
            executable = true;
            passAsFile = [ "code" ];
          }
          ''
            n=$out/bin/$name
            mkdir -p "$(dirname "$n")"
            mv "$codePath" code.cc
            $CXX code.cc -o "$n"
          '';
      }
      // derivationsOnly (pkgs.callPackage ./packages/glibc { }));

      apps = forAllSystems (system: pkgs: {
        default = mkApp (pkgs.writeShellScript "inspect-artifacts" ''
          set -euxo pipefail
          export PATH=${lib.makeBinPath (with pkgs; [ binutils gnugrep ])}
          nm ${pkgs.stdenv.cc.libc}/lib/libpthread.so.0 | grep pthread_atfork
        '');
      });

      legacyPackages = forAllSystems (_: pkgs: pkgs);
    };
}
