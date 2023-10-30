{ lib
, system
, glibc
, glibcLocales
, glibcLocalesUtf8
}:

let
  channels = import ./channels.nix { inherit system; };

  glibc-nixpkgs_2_17 = channels.pkgsGlibc_2_17.glibc;
  glibc-nixpkgs_2_24 = channels.pkgsGlibc_2_24.glibc;
  glibc-nixpkgs_2_25 = channels.pkgsGlibc_2_25.glibc;

  args_2_17 = {
    version = "2.17";
    old = glibc-nixpkgs_2_17;
    new = glibc;
    patches = [
      ./fix-symver.patch
      ./fix-configure.patch
    ];
    backportPatches = [ "fix-x64-abi.patch" ];
    inherit lib;
  };

  mkArgsLocale_2_17 = new: args_2_17 // {
    inherit new;
    old = channels.pkgsGlibc_2_17.glibcLocales;
    preBuild = ''
      ${new.preBuild or ""}

      # Hack to allow building of the locales (needed since glibc-2.12)
      sed -i -e "s,^LOCALEDEF=.*,LOCALEDEF=localedef --prefix=$TMPDIR," -e \
          /library-path/d ../glibc-2*/localedata/Makefile

      localedef --help \
        | grep -m1 -A1 'locale path *:' \
        | tr '\n' ' ' \
        | awk -F: '{ print $2 }' \
        | awk '{ $1 = $1 }; 1' \
        | xargs -I'{}' mkdir -p $TMPDIR/'{}'
    '';
  };
in
{
  glibc_2_17 = import ./common.nix args_2_17;
  glibcLocales_2_17 = import ./common.nix (mkArgsLocale_2_17 glibcLocales);
  glibcLocalesUtf8_2_17 =
    import ./common.nix (mkArgsLocale_2_17 glibcLocalesUtf8);

  glibc-nixpkgs = glibc;

  inherit glibc-nixpkgs_2_17 glibc-nixpkgs_2_24 glibc-nixpkgs_2_25;
}
