{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.services.athenz-authorization-proxy;

  q = lib.escapeShellArg;
  yaml = pkgs.formats.yaml { };
in
{
  options.services.athenz-authorization-proxy = {
    enable = lib.mkEnableOption "Athenz Authorization Proxy";

    package = lib.mkOption {
      type = lib.types.package;
      description = "Package to use for Athenz Authorization Proxy.";
    };

    settings = lib.mkOption {
      inherit (yaml) type;
      description = ''
        Settings for Athenz Authorization Proxy.

        See details below.

        <https://github.com/AthenZ/authorization-proxy/blob/master/docs/debug.md#configuration>
      '';
      example = {
        version = "v2.0.0";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    processes.athenz-authorization-proxy.exec = ''
      ${lib.getExe cfg.package} -f ${yaml.generate "config.yaml" cfg.settings}
    '';
  };
}
