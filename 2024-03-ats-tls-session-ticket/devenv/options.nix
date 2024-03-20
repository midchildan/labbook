{ lib, ... }:

let
  inherit (lib) types;
in
{
  options.labbook = {
    ports = {
      http = lib.mkOption {
        type = types.port;
        description = "HTTP port for ATS to listen on.";
        default = 8080;
      };

      https = lib.mkOption {
        type = types.port;
        description = "HTTP port for ATS to listen on.";
        default = 8443;
      };

      httpbin = lib.mkOption {
        type = types.port;
        description = "Port for httpbin to listen on.";
        default = 8081;
      };
    };
  };
}
