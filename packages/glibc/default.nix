{ lib
, system
, glibc
, glibcLocales
, nixpkgs-glibc-2-17
, nixpkgs-glibc-2-24
, nixpkgs-glibc-2-25
, ...
}:

let
  pkgsGlibc_2_17 = import nixpkgs-glibc-2-17 { inherit system; };
  pkgsGlibc_2_24 = import nixpkgs-glibc-2-24 { inherit system; };
  pkgsGlibc_2_25 = import nixpkgs-glibc-2-25 { inherit system; };
in
{
  glibc_2_17 = import ./common.nix {
    version = "2.17";
    old = pkgsGlibc_2_17.glibc;
    new = glibc;
    inherit lib;
  };

  glibcLocales_2_17 = import ./common.nix rec {
    version = "2.17";
    old = pkgsGlibc_2_17.glibcLocales;
    new = glibcLocales;
    preBuild = ''
      ${new.preBuild or ""}

      # Hack to allow building of the locales (needed since glibc-2.12)
      sed -i -e "s,^LOCALEDEF=.*,LOCALEDEF=localedef --prefix=$TMPDIR," -e \
          /library-path/d ../glibc-2*/localedata/Makefile
    '';
    inherit lib;
  };

  glibc_2_24 = import ./common.nix {
    version = "2.24";
    old = pkgsGlibc_2_24.glibc;
    new = glibc;
    inherit lib;
  };

  glibcLocales_2_24 = import ./common.nix {
    version = "2.24";
    old = pkgsGlibc_2_24.glibcLocales;
    new = glibcLocales;
    inherit lib;
  };

  glibc_2_25 = import ./common.nix {
    version = "2.25";
    old = pkgsGlibc_2_25.glibc;
    new = glibc;
    inherit lib;
  };

  glibcLocales_2_25 = import ./common.nix {
    version = "2.25";
    old = pkgsGlibc_2_25.glibcLocales;
    new = glibcLocales;
    inherit lib;
  };
}
