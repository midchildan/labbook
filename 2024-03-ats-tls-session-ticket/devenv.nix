{ lib, config, pkgs, ... }:

let
  cfg = config.labbook;
  atsCfg = config.services.trafficserver;
  httpbinAddr = "localhost:${toString cfg.ports.httpbin}";
  tlsCert = ../common/certs/localhost.crt;
  tlsKey = ../common/certs/localhost.key;
  session = "${config.env.DEVENV_ROOT}/session.pem";

  q = lib.escapeShellArg;

  inherit (pkgs) openssl;
in
{
  name = "Apache Traffic Server with TLS session tickets";

  imports = [
    ./devenv/options.nix
    ./devenv/httpbin.nix
    ./devenv/trafficserver
  ];

  packages = [ atsCfg.package openssl ];

  scripts = {
    connect = {
      description = "Receive a new session ticket.";

      # Send data to prevent the connection from being closed before ATS sends the
      # session ticket. Note that s_client interprets lines starting with "Q"
      # differently and closes the connection. The closure of the connection
      # happens after the session ticket is received.
      exec = ''
        set -x
        ${lib.getExe pkgs.openssl} s_client \
          -connect localhost:${toString cfg.ports.https} \
          -sess_out ${q session} \
          -CAfile ${tlsCert} \
          <<<'Q'
      '';
    };

    reconnect = {
      description = "Reuse an exisiting session ticket.";
      exec = ''
        set -x
        ${lib.getExe pkgs.openssl} s_client \
          -connect localhost:${toString cfg.ports.https} \
          -sess_in ${q session} \
          -CAfile ${tlsCert} \
          <<<'Q'
      '';
    };

    show = {
      description = "Show session ticket content.";
      exec = ''
        set -x
        ${lib.getExe pkgs.openssl} sess_id -in ${q session} -noout -text
      '';
    };
  };

  services.trafficserver = {
    enable = true;
    package = pkgs.enableDebugging pkgs.trafficserver;

    records.proxy.config = {
      diags.debug = {
        enabled = 1;
        tags = "ssl";
      };

      http = {
        server_ports =
          let
            http = toString cfg.ports.http;
            https = toString cfg.ports.https;
          in
          "${http} ${http}:ipv6 ${https}:ssl ${https}:ssl:ipv6";

        push_method_enabled = 1;

        # check that cache storage is usable before accepting traffic
        wait_for_cache = 2;
      };

      ssl.server = {
        session_ticket.number = 1;
        ticket_key.filename =
          let
            stek = lib.concatStringsSep "" [
              "name...........$"
              "aesKey.........$"
              "hmacKey........$"
            ];
            file = pkgs.writeText "stek.dat" stek;
          in
          toString file;
      };

      hostdb.host_file.path = "/etc/hosts";
      log.max_space_mb_headroom = 0;
    };

    remap = ''
      map / http://${httpbinAddr}
    '';

    sslMulticert = ''
      dest_ip=* ssl_cert_name=${tlsCert} ssl_key_name=${tlsKey}
    '';

    storage = "${atsCfg.runroot.cachedir} 256M";
  };

  services.httpbin = {
    enable = true;
    address = httpbinAddr;
  };
}
