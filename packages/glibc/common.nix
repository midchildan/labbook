{ lib
, version
, old
, new
, patches ? [ ]
, backportPatches ? [ ]
, ...
}@args:

let
  extraArgs = removeAttrs args [
    "lib"
    "old"
    "new"
    "patches"
    "backportPatches"
  ];
in
new.overrideAttrs (drv: ({
  inherit (old) name src configureFlags postPatch;

  patches =
    let
      oldPatches = old.patches or [ ];
      newPatches = lib.filter
        (patch: lib.elem (baseNameOf patch) backportPatches)
        (drv.patches or [ ]);
    in
    oldPatches ++ newPatches ++ patches;

  preBuild = old.preBuild or "";

  # Prevent compatiblity symlinks for deleted files overwriting the actual files
  # in older packages.
  # https://discourse.nixos.org/t/linking-issue-with-libpthread-from-glibc-2-17/34601
  postInstall = ''
    ln() {
      local dst="''${@: -1}"
      if [[ "$dst" == *.so && -f "$dst" ]]; then
        return
      fi
      command ln "$@"
    }

    ${drv.postInstall}

    unset -f ln
  '';

} // extraArgs))
