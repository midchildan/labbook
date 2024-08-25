{
  lib,
  stdenv,
  ardielle-tools,
  buildGoModule,
  fetchFromGitHub,
  fetchNpmDeps,
  go,
  maven,
  nodejs,
  npmHooks,
}:

let
  qs = lib.escapeShellArgs;
in
maven.buildMavenPackage rec {
  pname = "athenz-release";
  version = "1.11.64";

  src = fetchFromGitHub {
    owner = "AthenZ";
    repo = "athenz";
    rev = "v${version}";
    hash = "sha256-d57NpHyIFp96Mz+YaUiQrXILTUWdp6gBqU2t59gUGZU";
  };

  patches = [
    # prevent the build script from removing node_modules created by npmConfigHook
    ./build-dont-rm-node-modules.patch

    # don't `go install` external dependencies
    ./build-dont-go-install-external-deps.patch

    # setting GOPRIVATE makes the build impure by ignoring GOPROXY and reaching out to the internet
    ./build-dont-set-goprivate.patch

    ./fix-signedtoken-ipv6.patch
    ./fix-non-tty-password-input.patch
  ];

  mvnHash = "sha256-WX5YJ0j4TBOrO6uomDKYNDjjbkaIabckdfvSeX3y9y4=";

  inherit
    (buildGoModule {
      pname = "athenz-go-modules";
      inherit src version;
      proxyVendor = true;
      vendorHash = "sha256-GH7vl3iCXAvg7rs+ETjhCosC0iDHNnC9mFMpABBFsLQ=";
    })
    goModules
    ;

  npmRoot = "ui";
  npmDeps = fetchNpmDeps {
    src = "${src}/${npmRoot}";
    hash = "sha256-RqcxFq/UkMvgmySDObpacoelevT7bE2IBPSinMa2TW4=";
  };

  nativeBuildInputs = [
    go
    nodejs
    npmHooks.npmConfigHook
  ];

  preConfigure =
    let
      forEachNpmProject =
        shellCommandFor:
        lib.concatMapStringsSep "\n" (p: qs (shellCommandFor p)) [
          (rec {
            root = "clients/nodejs/zpe";
            lockfile = "${./zpe-lock.json}";
            deps = fetchNpmDeps {
              src = "${src}/${root}";
              postPatch = ''
                cp ${lockfile} package-lock.json
              '';
              hash = "sha256-BuPi96QF0y789Y0jHewzNfKJ9EahnatoQyIY+mC1+bc=";
            };
          })
          (rec {
            root = "clients/nodejs/zts";
            lockfile = "${./zts-lock.json}";
            deps = fetchNpmDeps {
              src = "${src}/${root}";
              postPatch = ''
                cp ${lockfile} package-lock.json
              '';
              hash = "sha256-DpQtes6EvXKWmSAXxY7o2+wPEEOCMvUQ3YUKVX0/gXc=";
            };
          })
          (rec {
            root = "libs/nodejs/auth_core";
            lockfile = "${./auth-core-lock.json}";
            deps = fetchNpmDeps {
              src = "${src}/${root}";
              postPatch = ''
                cp ${lockfile} package-lock.json
              '';
              hash = "sha256-gQ4ujKk3pnkxw7n+Co/bTWd52k5Hr1tzfnUTVSfiN6U=";
            };
          })
        ];
    in
    ''
      export GO111MODULE=on;
      export GOSUMDB=off;
      export GOTOOLCHAIN=local;
      export GOCACHE="$TMPDIR/go-cache";
      export GOPATH="$TMPDIR/go"
      export GOPROXY=file://${goModules}
      export PATH="$PATH''${PATH:+:}$GOPATH/bin"

      # The Athenz build script requires that the directory be made available beforehand
      mkdir -p "$GOPATH/bin"

      for f in ${ardielle-tools}/bin/*; do
        ln -sf "$f" "$GOPATH/bin"
      done

      runNpmConfig() (
        npmRoot="$1"
        npmDeps="$2"
        npmConfigHook
      )

      ${forEachNpmProject (p: [
        "install"
        "-m644"
        p.lockfile
        "${p.root}/package-lock.json"
      ])}
      ${forEachNpmProject (p: [
        "runNpmConfig"
        p.root
        p.deps
      ])}
    '';

  installPhase = ''
    mkdir $out
    find . -path './assembly/*/target/*.tar.gz' -exec mv '{}' $out \;
  '';

  mvnFetchExtraArgs = {
    inherit npmRoot npmDeps preConfigure;
  };

  # FIXME: Enable when https://github.com/NixOS/nix/pull/11270 is fixed
  doCheck = !stdenv.isDarwin;
  __darwinAllowLocalNetworking = doCheck;

  meta = {
    description = "X.509 certificate based service authentication and fine grained access control.";
    homepage = "https://www.athenz.io";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ midchildan ];
  };
}
