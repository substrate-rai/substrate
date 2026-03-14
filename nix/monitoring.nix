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
    provision.datasources.settings.datasources = [{
      name = "Prometheus";
      type = "prometheus";
      url = "http://localhost:9090";
      isDefault = true;
    }];
  };
}
