{ lib, config, pkgs, ... }:

let
  cfg = config.services.httpbin;
  python = pkgs.python3.withPackages
    (ps: with ps; [ httpbin gunicorn gevent ]);
in
{
  options.services.httpbin = {
    enable = lib.mkEnableOption "httpbin";
    address = lib.mkOption {
      type = lib.types.str;
      example = "localhost:8080";
      description = "Address to listen on";
    };
  };

  config = lib.mkIf cfg.enable {
    processes.httpbin.exec = ''
      ${python}/bin/gunicorn -b ${cfg.address} httpbin:app -k gevent;
    '';
  };
}
