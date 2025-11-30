############################
# KEYCLOAK METRICS SERVICE
############################

# Create a service for Keycloak metrics with Prometheus annotations
resource "kubernetes_service_v1" "keycloak_metrics" {
  metadata {
    name      = "keycloak-metrics"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/path"   = "/metrics"
      "prometheus.io/port"   = "8080"
    }
    labels = {
      app = "keycloak"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "keycloak"
    }

    port {
      name        = "metrics"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [helm_release.keycloak]
}

