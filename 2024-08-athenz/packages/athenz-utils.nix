{
  lib,
  stdenv,
  athenz-release,
}:

let
  q = lib.escapeShellArg;
  os = stdenv.hostPlatform.uname.system;
in
stdenv.mkDerivation (final: {
  pname = "athenz-utils";
  inherit (athenz-release) version meta;

  src = "${athenz-release}/${final.pname}-${final.version}-bin.tar.gz";

  buildPhase = ''
    runHook preBuild
    mv bin/${q (lib.toLower os)}/* bin
    rm -rf bin/{darwin,linux,windows}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/doc/athenz-utils
    mv LICENSE $out/share/doc/athenz-utils
    mv * $out
    runHook postInstall
  '';

  passthru = {
    inherit (athenz-release) JAVA_HOME;
  };
})
