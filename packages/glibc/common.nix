{ lib
, version
, old
, new
, ...
}@args:

let
  extraArgs = removeAttrs args [ "lib" "old" "new" ];
in
new.overrideAttrs (drv: ({
  inherit (old) name src configureFlags postPatch;

  patches =
    let
      oldPatches = old.patches or [ ];
      newPatches = drv.patches or [ ];
      argPatches = args.patches or [ ];

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
    oldPatches ++ backportPatches ++ localPatches ++ argPatches;

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
}
  // extraArgs))
