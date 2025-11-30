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

resource "kubernetes_ingress_v1" "typesense_api_staging" {
  metadata {
    name      = "typesense-api-staging"
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

resource "kubernetes_ingress_v1" "typesense_dashboard_staging" {
  metadata {
    name      = "typesense-dashboard-staging"
    namespace = kubernetes_namespace.infra_staging.metadata[0].name
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "typesense-staging.helios"

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

############################
# INGRESS — STAGING (APPS)
############################

# resource "kubernetes_ingress_v1" "aspire_staging" {
#   metadata {
#     name      = "aspire-staging"
#     namespace = kubernetes_namespace.apps_staging.metadata[0].name
#   }
# 
#   spec {
#     ingress_class_name = "nginx"
# 
#     rule {
#       host = "aspire-staging.helios"
# 
#       http {
#         path {
#           path      = "/"
#           path_type = "Prefix"
# 
#           backend {
#             service {
#               name = "aspire-staging"
#               port {
#                 number = 18888
#               }
#             }
#           }
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_ingress_v1" "questions_api_staging" {
#   metadata {
#     name      = "questions-api-staging"
#     namespace = kubernetes_namespace.apps_staging.metadata[0].name
#   }
# 
#   spec {
#     ingress_class_name = "nginx"
# 
#     rule {
#       host = "questions-api-staging.helios"
# 
#       http {
#         path {
#           path      = "/"
#           path_type = "Prefix"
# 
#           backend {
#             service {
#               name = "questions-api-staging"
#               port {
#                 number = 7001
#               }
#             }
#           }
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_ingress_v1" "search_api_staging" {
#   metadata {
#     name      = "search-api-staging"
#     namespace = kubernetes_namespace.apps_staging.metadata[0].name
#   }
# 
#   spec {
#     ingress_class_name = "nginx"
# 
#     rule {
#       host = "search-api-staging.helios"
# 
#       http {
#         path {
#           path      = "/"
#           path_type = "Prefix"
# 
#           backend {
#             service {
#               name = "search-api-staging"
#               port {
#                 number = 7002
#               }
#             }
#           }
#         }
#       }
#     }
#   }
# }

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

resource "kubernetes_ingress_v1" "typesense_api_production" {
  metadata {
    name      = "typesense-dashboard-ui-production"
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

resource "kubernetes_ingress_v1" "typesense_dashboard_production" {
  metadata {
    name      = "typesense-dashboard-production"
    namespace = kubernetes_namespace.infra_production.metadata[0].name
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "typesense-production.helios"

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

############################
# INGRESS — PRODUCTION (APPS)
############################

# resource "kubernetes_ingress_v1" "aspire_production" {
#   metadata {
#     name      = "aspire-production"
#     namespace = kubernetes_namespace.apps_production.metadata[0].name
#   }
# 
#   spec {
#     ingress_class_name = "nginx"
# 
#     rule {
#       host = "aspire-production.helios"
# 
#       http {
#         path {
#           path      = "/"
#           path_type = "Prefix"
# 
#           backend {
#             service {
#               name = "aspire-production"
#               port {
#                 number = 18888
#               }
#             }
#           }
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_ingress_v1" "questions_api_production" {
#   metadata {
#     name      = "questions-api-production"
#     namespace = kubernetes_namespace.apps_production.metadata[0].name
#   }
# 
#   spec {
#     ingress_class_name = "nginx"
# 
#     rule {
#       host = "questions-api-production.helios"
# 
#       http {
#         path {
#           path      = "/"
#           path_type = "Prefix"
# 
#           backend {
#             service {
#               name = "questions-api-production"
#               port {
#                 number = 7001
#               }
#             }
#           }
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_ingress_v1" "search_api_production" {
#   metadata {
#     name      = "search-api-production"
#     namespace = kubernetes_namespace.apps_production.metadata[0].name
#   }
# 
#   spec {
#     ingress_class_name = "nginx"
# 
#     rule {
#       host = "search-api-production.helios"
# 
#       http {
#         path {
#           path      = "/"
#           path_type = "Prefix"
# 
#           backend {
#             service {
#               name = "search-api-production"
#               port {
#                 number = 7002
#               }
#             }
#           }
#         }
#       }
#     }
#   }
# }

