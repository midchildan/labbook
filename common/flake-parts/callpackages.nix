{
  lib,
  flake-parts-lib,
  inputs,
  ...
}:

let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (inputs.self.lib) collectPackages;
in
{
  options.perSystem = mkPerSystemOption {
    options.callPackages = {
      enable = lib.mkEnableOption "imports of all packages defined in the specified directory";

      directory = lib.mkOption {
        description = "The directory from which packages should be imported.";
        type = lib.types.path;
      };

      extraPackages = lib.mkOption {
        description = "Additional packages to include in the package set.";
        type = with lib.types; functionTo (lazyAttrsOf anything);
        default = self: {};
        defaultText = lib.literalExpression "self: {}";
        example = lib.literalExpression ''
          self: {
            foo = self.callPackage ./foo { stdenv = clangStdenv; };
          }
        '';
      };
    };
  };

  config.flake.lib = rec {
    flattenAttrs = lib.foldlAttrs (
      acc: name: value:
      if lib.isDerivation value || !lib.isAttrs value then
        if lib.hasAttr name acc then
          throw "flattenAttrs: conflicting definitions for attribute \"${name}\""
        else
          acc // { ${name} = value; }
      else
        acc // flattenAttrs value
    ) { };

    collectLegacyPackages =
      attrs@{ pkgs, ... }:
      packagesFn:
      let
        autoCalledPkgs =
          self:
          lib.packagesFromDirectoryRecursive (
            { inherit (self) callPackage; } // lib.removeAttrs attrs [ "pkgs" ]
          );

        packagesFn' = self: { callPackages = lib.callPackagesWith (pkgs // self); } // packagesFn self;

        overlay = lib.flip (_: packagesFn');

        isAvailable =
          drv:
          lib.any (pred: pred drv) [
            (lib.meta.availableOn { inherit (pkgs.stdenv.hostPlatform) system; })
            (drv: !lib.isDerivation drv)
          ];

        allPackages = lib.makeScope pkgs.newScope (lib.extends overlay autoCalledPkgs);
      in
      lib.filterAttrsRecursive (_: isAvailable) allPackages;

    collectPackages =
      attrs: packagesFn:
      let
        allPackages = collectLegacyPackages attrs packagesFn;
      in
      lib.filterAttrs (_: lib.isDerivation) (flattenAttrs allPackages);
  };

  config.perSystem = { config, pkgs, ... }:
    let
      cfg = config.callPackages;
    in
    lib.mkIf cfg.enable {
      packages =
        collectPackages
          {
            inherit pkgs;
            inherit (cfg) directory;
          }
          cfg.extraPackages;
      };
}
