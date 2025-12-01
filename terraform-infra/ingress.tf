############################
# INGRESS CONTROLLER
############################

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  namespace        = kubernetes_namespace.ingress.metadata[0].name
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.14.0"
  create_namespace = false
}

############################
# KEYCLOAK INGRESS
############################

resource "kubernetes_ingress_v1" "keycloak_global" {
  metadata {
    name      = "keycloak-global"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
    labels = {
      app = "keycloak"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "keycloak.helios"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "keycloak"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.keycloak]
}

############################
# INGRESS — STAGING (INFRA)
############################

resource "kubernetes_ingress_v1" "rabbitmq_staging" {
  metadata {
    name      = "rabbitmq-staging"
    namespace = kubernetes_namespace.infra_staging.metadata[0].name
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "overflow-rabbit-staging.helios"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "rabbitmq-staging"
              port {
                number = 15672
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.rabbitmq_staging]
}


resource "kubernetes_ingress_v1" "typesense_dashboard_staging" {
  metadata {
    name      = "typesense-dashboard-staging"
    namespace = kubernetes_namespace.infra_staging.metadata[0].name
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "overflow-typesense-staging.helios"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "typesense-dashboard"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.typesense_dashboard_staging]
}

# Typesense API endpoint for dashboard to connect to
resource "kubernetes_ingress_v1" "typesense_api_endpoint_staging" {
  metadata {
    name      = "typesense-api-staging"
    namespace = kubernetes_namespace.infra_staging.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/cors-allow-origin"  = "*"
      "nginx.ingress.kubernetes.io/cors-allow-methods" = "GET, POST, PUT, DELETE, OPTIONS"
      "nginx.ingress.kubernetes.io/cors-allow-headers" = "DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization,X-TYPESENSE-API-KEY"
      "nginx.ingress.kubernetes.io/enable-cors"        = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "overflow-typesense-api-staging.helios"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "typesense"
              port {
                number = 8108
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_stateful_set.typesense_staging]
}

############################
# INGRESS — PRODUCTION (INFRA)
############################

resource "kubernetes_ingress_v1" "rabbitmq_production" {
  metadata {
    name      = "rabbitmq-production"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "overflow-rabbit.helios"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "rabbitmq-production"
              port {
                number = 15672
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.rabbitmq_production]
}

resource "kubernetes_ingress_v1" "typesense_dashboard_ui_production" {
  metadata {
    name      = "typesense-dashboard-ui"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "overflow-typesense.helios"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "typesense-dashboard"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.typesense_dashboard_production]
}

# Typesense API endpoint for dashboard to connect to
resource "kubernetes_ingress_v1" "typesense_api_endpoint_production" {
  metadata {
    name      = "typesense-api-production"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/cors-allow-origin"  = "*"
      "nginx.ingress.kubernetes.io/cors-allow-methods" = "GET, POST, PUT, DELETE, OPTIONS"
      "nginx.ingress.kubernetes.io/cors-allow-headers" = "DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization,X-TYPESENSE-API-KEY"
      "nginx.ingress.kubernetes.io/enable-cors"        = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "overflow-typesense-api.helios"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "typesense"
              port {
                number = 8108
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_stateful_set.typesense_production]
}
