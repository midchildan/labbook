{ lib
, glibc
, glibc-2_17
}:

let
  oldPatches = glibc-2_17.patches or [ ];
  newPatches = glibc.patches or [ ];

  backportPatches = lib.filter
    (patch: lib.elem (baseNameOf patch) [
      "fix-x64-abi.patch"
    ])
    newPatches;

  localPatches = [
    ./fix-symver.patch
    ./fix-configure.patch
  ];
in
glibc.overrideAttrs (_: {
  inherit (glibc-2_17) name src configureFlags postPatch;
  version = "2.17";

  patches = oldPatches ++ backportPatches ++ localPatches;
})
