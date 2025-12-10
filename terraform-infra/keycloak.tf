############################
# KEYCLOAK (cloudpirates / OCI)
############################

resource "helm_release" "keycloak" {
  name             = "keycloak"
  namespace        = kubernetes_namespace.infra_production.metadata[0].name
  repository       = "oci://registry-1.docker.io/cloudpirates"
  chart            = "keycloak"
  create_namespace = false

  depends_on = [kubernetes_namespace.infra_production]

  set {
    name  = "keycloak.adminUser"
    value = var.keycloak_admin_user
  }

  set_sensitive {
    name  = "keycloak.adminPassword"
    value = var.keycloak_admin_password
  }

  # Enable embedded PostgreSQL database
  set {
    name  = "postgres.enabled"
    value = "true"
  }

  set {
    name  = "postgres.auth.database"
    value = "keycloak"
  }

  set {
    name  = "postgres.auth.username"
    value = "postgres"
  }

  set_sensitive {
    name  = "postgres.auth.password"
    value = var.keycloak_postgres_password
  }

  # Enable metrics endpoint
  set {
    name  = "keycloak.metrics.enabled"
    value = "true"
  }
}

