variable "kubeconfig_path" {
  type        = string
  default     = "~/.kube/config"
  description = "Path to kubeconfig for k3s cluster."
}

variable "enable_typesense_clusters" {
  type        = bool
  default     = false
  description = "Create TypesenseCluster resources (set to true only after the CRD is installed)."
}

# Postgres passwords
variable "pg_staging_password" {
  type      = string
  sensitive = true
}

variable "pg_production_password" {
  type      = string
  sensitive = true
}

# RabbitMQ passwords
variable "rabbit_staging_password" {
  type      = string
  sensitive = true
}

variable "rabbit_production_password" {
  type      = string
  sensitive = true
}

# Typesense API keys
variable "typesense_staging_api_key" {
  type      = string
  sensitive = true
}

variable "typesense_production_api_key" {
  type      = string
  sensitive = true
}

# Keycloak admin
variable "keycloak_admin_user" {
  type    = string
  default = "admin"
}

variable "keycloak_admin_password" {
  type      = string
  sensitive = true
}

variable "keycloak_postgres_password" {
  type      = string
  sensitive = true
  default   = "postgres"
}

# Grafana admin
variable "grafana_admin_password" {
  type      = string
  sensitive = true
  default   = "admin"
}
