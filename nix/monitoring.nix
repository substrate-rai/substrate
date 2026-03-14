{ config, pkgs, ... }:

{
  services.prometheus = {
    enable = true;
    port = 9090;
    retentionTime = "30d";
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{ targets = [ "localhost:9100" ]; }];
      }
      {
        job_name = "nvidia";
        static_configs = [{ targets = [ "localhost:9835" ]; }];
      }
    ];
  };

  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" "processes" ];
  };

  services.grafana = {
    enable = true;
    settings.server = {
      http_addr = "127.0.0.1";
      http_port = 3000;
    };
    settings.security.secret_key = "$__file{/run/keys/grafana-secret}";
    provision.datasources.settings.datasources = [{
      name = "Prometheus";
      type = "prometheus";
      url = "http://localhost:9090";
      isDefault = true;
    }];
  };

  # Generate a Grafana secret key if it doesn't exist
  systemd.services.grafana-secret = {
    description = "Generate Grafana secret key";
    wantedBy = [ "grafana.service" ];
    before = [ "grafana.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -f /run/keys/grafana-secret ]; then
        mkdir -p /run/keys
        ${pkgs.openssl}/bin/openssl rand -hex 32 > /run/keys/grafana-secret
        chmod 400 /run/keys/grafana-secret
      fi
    '';
  };
}
