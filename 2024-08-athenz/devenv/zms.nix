{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.services.athenz-zms;
  q = lib.escapeShellArg;

  javaProperties = pkgs.formats.javaProperties { };
  json = pkgs.formats.json { };

  openssl = lib.getExe pkgs.openssl;
  mysql = "${config.services.mysql.package}/bin/mysql";

  runtimeDir = "${config.env.DEVENV_RUNTIME}/athenz-zms";
  stateDir = "${config.env.DEVENV_STATE}/athenz-zms";
  logDir = "${stateDir}/logs";
  jettyTempDir = "${stateDir}/jetty";

  certPath = "${stateDir}/cert.pem";
  keyPath = "${stateDir}/key.pem";
  privateKeyPath = "${stateDir}/private.pem";
  keystorePath = "${stateDir}/keystore.pkcs12";
  certCfgPath = "${cfg.package}/conf/zms_server/dev_x509_cert.cnf";

  logConfigFile =
    pkgs.runCommand "logback.xml"
      {
        nativeBuildInputs = [ pkgs.xmlstarlet ];
      }
      ''
        xml ed -u '/configuration/property[@name="LOG_DIR"]/@value' -v ${q logDir} \
          ${cfg.package}/conf/zms_server/logback.xml \
          > $out
      '';

  athenzPropFile = javaProperties.generate "athenz.properties" cfg.properties.athenz;
  zmsPropFile = javaProperties.generate "zms.properties" cfg.properties.zms;
  authzServicesFile = json.generate "authorized_services.json" cfg.authorizedServices;
  solutionTemplatesFile = json.generate "solution_templates.json" cfg.solutionTemplates;

  dbName = "zms_server";
  dbUser = cfg.properties.zms."athenz.zms.jdbc_user";
  dbPassword = cfg.properties.zms."athenz.zms.jdbc_password";
  dbPort = toString config.services.mysql.settings.mysqld.port;
  dbUrl = "jdbc:mysql://localhost:${dbPort}/${dbName}";
in
{
  options.services.athenz-zms = {
    enable = lib.mkEnableOption "Athenz ZMS";

    package = lib.mkOption {
      type = lib.types.package;
      description = "ZMS package to use.";
    };

    properties.athenz = lib.mkOption {
      inherit (javaProperties) type;
      description = "Java properties for Athenz.";
      # defaults taken from ${cfg.package}/conf/zms_server/athenz.properties
      default = {
        "athenz.tls_port" = 4443;
        "athenz.port" = 0;
        "athenz.ssl_key_store_type" = "PKCS12";
        "athenz.ssl_key_store_password" = "INSECURE-DEFAULT";
      };
    };

    properties.zms = lib.mkOption {
      inherit (javaProperties) type;
      description = "Java properties for ZMS.";
      # defaults taken from ${cfg.package}/conf/zms_server/zms.properties
      default = {
        "athenz.auth.private_key_store.private_key_id" = 0;
        "athenz.zms.authority_classes" = lib.concatStringsSep "," [
          "com.yahoo.athenz.auth.impl.PrincipalAuthority"
          "com.yahoo.athenz.auth.impl.TestUserAuthority"
        ];
        "athenz.zms.domain_admin" = "user.admin";
        "athenz.zms.jdbc_store" = dbUrl;
        "athenz.zms.jdbc_user" = "zms_admin";
        "athenz.zms.jdbc_password" = "INSECURE-DEFAULT";
        "athenz.zms.no_auth_uri_list" = "/zms/v1/status";
        "athenz.zms.object_store_factory_class" = "com.yahoo.athenz.zms.store.impl.JDBCObjectStoreFactory";
        "athenz.zms.read_only_mode" = false;
      };
    };

    authorizedServices = lib.mkOption {
      inherit (json) type;
      description = ''
        Configure which ZMS APIs clients are able to access.

        <https://github.com/AthenZ/athenz/blob/master/docker/docs/IdP/Auth0.md#about-authorized-service>
      '';
      default = { };
      example = {
        services.testing-domain.my-athenz-spa.allowedOperations = [
          { name = "posttopleveldomain"; }
        ];
      };
    };

    solutionTemplates = lib.mkOption {
      inherit (json) type;
      default = {
        templates = { };
      };
      description = ''
        Configures a collection of predefined roles, policies, and services that can be applied on a
        domain.

        <https://athenz.github.io/athenz/athenz_templates/>
      '';
    };

    certPath = lib.mkOption {
      description = "Path to ZMS server certificate.";
      default = certPath;
      readOnly = true;
    };
  };

  config = lib.mkIf cfg.enable {
    # see ${cfg.package}/bin/setup_dev_zms.sh
    enterShell = ''
      if [[ ! -d ${q stateDir} ]]; then
        mkdir -p ${q runtimeDir} ${q stateDir}
        ${openssl} genrsa -out ${q privateKeyPath} 2048
        ${openssl} req -x509 -nodes -newkey rsa:2048 -days 365 \
          -keyout ${q keyPath} \
          -out ${q certPath} \
          -config <(sed 's/__athenz_hostname__/localhost/g' ${q certCfgPath})
        ${openssl} pkcs12 -export -noiter \
          -password pass:${q cfg.properties.athenz."athenz.ssl_key_store_password"} \
          -out ${q keystorePath} \
          -in ${q certPath} \
          -inkey ${q keyPath}
      fi
      mkdir -p ${q jettyTempDir}
    '';

    processes.zms.exec = ''
      set -euo pipefail

      while ! ${mysql} --no-defaults -u ${q dbUser} -p${q dbPassword} -e 'use ${dbName}'; do
        echo "Waiting for MySQL to come up."
        sleep 5
      done

      ${cfg.package.JAVA_HOME}/bin/java \
        -classpath "${cfg.package}/lib/jars/*" \
        -Dathenz.root_dir=${cfg.package} \
        -Dathenz.jetty_home=${cfg.package} \
        -Dathenz.jetty_temp=${q jettyTempDir} \
        -Dathenz.zms.root_dir=${cfg.package} \
        -Dathenz.prop_file=${athenzPropFile} \
        -Dathenz.zms.prop_file=${zmsPropFile} \
        -Dlogback.configurationFile=${logConfigFile} \
        -Dathenz.ssl_key_store=${q keystorePath} \
        -Dathenz.access_log_dir=${q logDir} \
        -Dathenz.auth.private_key_store.private_key=${q privateKeyPath} \
        -Dathenz.zms.authz_service_fname=${authzServicesFile} \
        -Dathenz.zms.solution_templates_fname=${solutionTemplatesFile} \
        com.yahoo.athenz.container.AthenzJettyContainer
    '';

    services.mysql = {
      enable = true;
      ensureUsers = [
        {
          name = dbUser;
          password = dbPassword;
          ensurePermissions = {
            "${dbName}.*" = "ALL PRIVILEGES";
          };
        }
      ];
      initialDatabases = [
        {
          name = dbName;
          schema = "${cfg.package.schema}/zms_server.sql";
        }
      ];
    };
  };
}
