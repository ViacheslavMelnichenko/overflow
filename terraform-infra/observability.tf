############################
# GRAFANA (Visualization)
############################

resource "helm_release" "grafana" {
  name       = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "10.2.0"

  depends_on = [kubernetes_namespace.monitoring, helm_release.loki, helm_release.tempo, helm_release.prometheus, helm_release.ingress_nginx]

  set {
    name  = "adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "ingress.enabled"
    value = "true"
  }

  set {
    name  = "ingress.ingressClassName"
    value = "nginx"
  }

  set {
    name  = "ingress.hosts[0]"
    value = "overflow-grafana.helios"
  }

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.size"
    value = "10Gi"
  }

  # Configure datasources via values
  set {
    name  = "datasources.datasources\\.yaml.apiVersion"
    value = "1"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].name"
    value = "Loki"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].type"
    value = "loki"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].access"
    value = "proxy"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].url"
    value = "http://loki:3100"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].isDefault"
    value = "true"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[1].name"
    value = "Tempo"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[1].type"
    value = "tempo"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[1].access"
    value = "proxy"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[1].url"
    value = "http://tempo:3100"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[2].name"
    value = "Prometheus"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[2].type"
    value = "prometheus"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[2].access"
    value = "proxy"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[2].url"
    value = "http://prometheus-server"
  }

}

############################
# LOKI (Log Aggregation)
############################

resource "helm_release" "loki" {
  name       = "loki"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = "2.10.0"


  set {
    name  = "loki.enabled"
    value = "true"
  }

  set {
    name  = "promtail.enabled"
    value = "true"
  }

  set {
    name  = "grafana.enabled"
    value = "false" # We already have Grafana
  }

  set {
    name  = "loki.persistence.enabled"
    value = "true"
  }

  set {
    name  = "loki.persistence.size"
    value = "10Gi"
  }
}

############################
# TEMPO (Distributed Tracing)
############################

resource "helm_release" "tempo" {
  name       = "tempo"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = "1.7.0"


  set {
    name  = "tempo.receivers.otlp.protocols.http.endpoint"
    value = "0.0.0.0:4318"
  }

  set {
    name  = "tempo.receivers.otlp.protocols.grpc.endpoint"
    value = "0.0.0.0:4317"
  }

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.size"
    value = "10Gi"
  }
}

############################
# PROMETHEUS (Metrics)
############################

resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = "25.8.0"

  depends_on = [kubernetes_namespace.monitoring, helm_release.ingress_nginx]


  set {
    name  = "server.ingress.enabled"
    value = "true"
  }

  set {
    name  = "server.ingress.ingressClassName"
    value = "nginx"
  }

  set {
    name  = "server.ingress.hosts[0]"
    value = "overflow-prometheus.helios"
  }

  set {
    name  = "server.persistentVolume.enabled"
    value = "true"
  }

  set {
    name  = "server.persistentVolume.size"
    value = "10Gi"
  }

  set {
    name  = "alertmanager.enabled"
    value = "false" # Disable for now, can enable later
  }
}

