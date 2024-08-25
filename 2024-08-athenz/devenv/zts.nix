{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.services.athenz-zts;

  q = lib.escapeShellArg;

  javaProperties = pkgs.formats.javaProperties { };
  json = pkgs.formats.json { };

  curl = lib.getExe pkgs.curl;
  openssl = lib.getExe pkgs.openssl;
  keytool = "${cfg.package.JAVA_HOME}/bin/keytool";

  runtimeDir = "${config.env.DEVENV_RUNTIME}/athenz-zts";
  stateDir = "${config.env.DEVENV_STATE}/athenz-zts";
  logDir = "${stateDir}/logs";
  jettyTempDir = "${stateDir}/jetty";

  certPath = "${stateDir}/cert.pem";
  keyPath = "${stateDir}/key.pem";
  csrPath = "${stateDir}/zts.csr";
  publicKeyPath = "${stateDir}/public.pem";
  privateKeyPath = "${stateDir}/private.pem";
  selfCaPath = "${stateDir}/selfCa.pem";
  keyStorePath = "${stateDir}/keystore.pkcs12";
  trustStorePath = "${stateDir}/truststore.jks";
  clientTrustStorePath = "${stateDir}/clientstore.jks";
  caCfgPath = "${cfg.package}/conf/zts_server/dev_x509ca_cert.cnf";
  certCfgPath = "${cfg.package}/conf/zts_server/dev_x509_cert.cnf";
  extCfgPath = "${cfg.package}/conf/zts_server/dev_x509_ext.cnf";
  selfCfgPath = "${cfg.package}/conf/zts_server/self_x509_cert.cnf";
  nTokenPath = "${runtimeDir}/zms-admin.ntoken";

  storePass = "INSECURE-DEFAULT";
  clientStorePass = "INSECURE-DEFAULT";

  logConfigFile =
    pkgs.runCommand "logback.xml"
      {
        nativeBuildInputs = [ pkgs.xmlstarlet ];
      }
      ''
        xml ed -u '/configuration/property[@name="LOG_DIR"]/@value' -v ${q logDir} \
          ${cfg.package}/conf/zts_server/logback.xml \
          > $out
      '';

  ztsCfg = config.services.athenz-zts;
  ztsPort = ztsCfg.properties.athenz."athenz.tls_port";
  athenzConfPath = "${stateDir}/athenz.conf";
  athenzPropFile = javaProperties.generate "athenz.properties" cfg.properties.athenz;
  ztsPropFile = javaProperties.generate "zts.properties" cfg.properties.zts;

  zmsCfg = config.services.athenz-zms;
  zmsBaseUrl = "${lib.removeSuffix "/" cfg.zmsUrl}/zms/v1";
in
{
  options.services.athenz-zts = {
    enable = lib.mkEnableOption "Athenz ZTS";

    package = lib.mkOption {
      type = lib.types.package;
      description = "ZTS package to use.";
    };

    properties.athenz = lib.mkOption {
      inherit (javaProperties) type;
      description = "Java properties for Athenz.";
      # defaults taken from ${cfg.package}/conf/zts_server/athenz.properties
      default = {
        "athenz.tls_port" = 8443;
        "athenz.port" = 0;
        "athenz.ssl_key_store_password" = storePass;
        "athenz.ssl_trust_store_password" = clientStorePass;
      };
    };

    properties.zts = lib.mkOption {
      inherit (javaProperties) type;
      description = "Java properties for ZTS.";
      # defaults taken from ${cfg.package}/conf/zms_server/zts.properties
      default = {
        "athenz.zts.authority_classes" = lib.concatStringsSep "," [
          "com.yahoo.athenz.auth.impl.PrincipalAuthority"
          "com.yahoo.athenz.auth.impl.CertificateAuthority"
        ];
        "athenz.auth.private_key_store.private_key_id" = 0;
        "athenz.zts.ssl_key_store_password" = storePass;
        "athenz.zts.ssl_trust_store_password" = storePass;
        "javax.net.ssl.trustStorePassword" = storePass;
        "athenz.zts.self_signer_private_key_fname" = privateKeyPath;
        "athenz.zts.self_signer_cert_dn" = "cn=Devenv Athenz CA";
        "athenz.zts.cert_signer_factory_class" = "com.yahoo.athenz.zts.cert.impl.SelfCertSignerFactory";
        "athenz.zts.cert_record_store_factory_class" = "com.yahoo.athenz.zts.cert.impl.FileCertRecordStoreFactory";
        "athenz.zts.cert_file_store_path" = stateDir;
        "athenz.zts.cert_file_store_name" = "cert-records";
        "athenz.zts.provider.ssl_client_trust_store" = clientTrustStorePath;
        "athenz.zts.provider.ssl_client_trust_store_password" = clientStorePass;
        "athenz.zts.change_log_store_dir" = stateDir;
        "athenz.zts.no_auth_uri_list" = "/zts/v1/status";
      };
    };

    zmsUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://localhost:${zmsCfg.properties.athenz."athenz.tls_port"}";
      description = "URL of the ZMS instance.";
    };

    zmsCert = lib.mkOption {
      type = lib.types.path;
      default = zmsCfg.certPath;
      description = "Path to TLS certificate for ZMS.";
    };

    caPath = lib.mkOption {
      description = "Path to certificate authority for the ZTS TLS certificate.";
      default = "${stateDir}/ca.pem";
      readOnly = true;
    };
  };

  config = lib.mkIf cfg.enable {
    # see ${cfg.package}/bin/setup_dev_zts.sh
    enterShell = ''
      if [[ ! -f ${q keyStorePath} ]]; then
        mkdir -p ${q runtimeDir} ${q stateDir} ${q jettyTempDir}

        # generate key pair
        ${openssl} genrsa -out ${q privateKeyPath} 2048
        ${openssl} rsa -in ${q privateKeyPath} -pubout > ${q publicKeyPath}

        # generate CA
        ${openssl} req -x509 -nodes -newkey rsa:2048 -days 3650 \
          -keyout ${q keyPath} \
          -out ${q cfg.caPath} \
          -config ${caCfgPath}

        # generate cert
        ${openssl} req -new \
          -key ${q keyPath} \
          -out ${q csrPath} \
          -config <(sed 's/__athenz_hostname__/localhost/g' ${certCfgPath})
        ${openssl} x509 -req -days 365 -CAcreateserial \
          -CA ${q cfg.caPath} \
          -CAkey ${q keyPath} \
          -in ${q csrPath} \
          -out ${q certPath} \
          -extfile <(sed 's/__athenz_hostname__/localhost/g' ${extCfgPath})

        # generate PKCS#12 keystore
        ${openssl} pkcs12 -export -noiter \
          -password pass:${q storePass} \
          -out ${q keyStorePath} \
          -in ${q certPath} \
          -inkey ${q keyPath}

        # generate truststore for ZTS clients
        ${openssl} req -x509 -nodes -days 3650 \
          -key ${q privateKeyPath} \
          -out ${q selfCaPath} \
          -config ${selfCfgPath}
        ${keytool} -importcert -noprompt -alias self \
          -keystore ${q clientTrustStorePath} \
          -file ${q selfCaPath} \
          -storepass ${q clientStorePass}
      fi
    '';

    processes.zts.exec = ''
      set -euo pipefail

      ZMS_ADMIN=${q zmsCfg.properties.zms."athenz.zms.domain_admin"}

      if [[ ! -f ${q trustStorePath} ]]; then
        # generate truststore for connecting to ZMS
        ${keytool} -importcert -noprompt -alias zms \
          -keystore ${q trustStorePath} \
          -file ${q cfg.zmsCert} \
          -storepass ${q storePass}
      fi

      while ! ${curl} -sSf --cacert ${cfg.zmsCert} ${zmsBaseUrl}/status; do
        echo "Waiting for ZMS to come up."
        sleep 5
      done

      zms-cli() {
        ${cfg.package}/bin/zms-cli \
          -c ${q cfg.zmsCert} \
          -z ${zmsBaseUrl} \
          "$@"
      }

      if [[ ! -f ${q athenzConfPath} ]]; then
        zms-cli -i "$ZMS_ADMIN" -x get-user-token <<<"''${ZMS_ADMIN#user.}" \
          | tail -n1 \
          > ${q nTokenPath}
        zms-cli -f ${q nTokenPath} -d sys.auth delete-service zts || true
        zms-cli -f ${q nTokenPath} -d sys.auth add-service zts 0 ${q publicKeyPath}

        ${cfg.package}/bin/athenz-conf \
          -c ${q cfg.zmsCert} \
          -o ${q athenzConfPath} \
          -z ${q cfg.zmsUrl} \
          -t https://localhost:${ztsPort} \
          <<<"''${ZMS_ADMIN#user.}\n"
      fi

      ${cfg.package.JAVA_HOME}/bin/java \
        -classpath "${cfg.package}/lib/jars/*" \
        -Dathenz.root_dir=${cfg.package} \
        -Dathenz.jetty_home=${cfg.package} \
        -Dathenz.jetty_temp=${q jettyTempDir} \
        -Dathenz.zts.root_dir=${cfg.package} \
        -Dathenz.athenz_conf=${athenzConfPath} \
        -Dathenz.prop_file=${athenzPropFile} \
        -Dathenz.zts.prop_file=${ztsPropFile} \
        -Dlogback.configurationFile=${logConfigFile} \
        -Dathenz.ssl_key_store=${q keyStorePath} \
        -Dathenz.ssl_trust_store=${q clientTrustStorePath} \
        -Dathenz.zts.ssl_key_store=${q keyStorePath} \
        -Dathenz.zts.ssl_trust_store=${q trustStorePath} \
        -Djavax.net.ssl.trustStore=${q trustStorePath} \
        -Dathenz.access_log_dir=${q logDir} \
        -Dathenz.auth.private_key_store.private_key=${q privateKeyPath} \
        -Dathenz.zts.self_signer_private_key_fname=${q privateKeyPath} \
        com.yahoo.athenz.container.AthenzJettyContainer
    '';
  };
}
