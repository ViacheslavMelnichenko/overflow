# Ingress Architecture

This document explains how ingress routing is configured in the Overflow project.

## Overview

The project uses a **separation of concerns** approach for ingress configuration:

- **Infrastructure Services** → Managed by Terraform (`terraform-infra/ingress.tf`)
- **Application Services** → Managed by Kustomize (`k8s/overlays/{env}/ingress.yaml`)

## Architecture Diagram

```
External Traffic
      ↓
NGINX Ingress Controller (deployed by Terraform)
      ↓
      ├─→ Infrastructure Services (Terraform-managed ingress)
      │   ├─→ keycloak.helios → Keycloak
      │   ├─→ overflow-rabbit-staging.helios → RabbitMQ (staging)
      │   ├─→ overflow-typesense-staging.helios → Typesense Dashboard (staging)
      │   └─→ overflow-rabbit.helios → RabbitMQ (production)
      │
      └─→ Application Services (Kustomize-managed ingress)
          ├─→ overflow-api-staging.helios
          │   ├─→ /questions → question-svc:8080/questions
          │   └─→ /search → search-svc:8080/api/search (rewritten)
          │
          └─→ overflow-api.helios (production)
              ├─→ /questions → question-svc:8080/questions
              └─→ /search → search-svc:8080/api/search (rewritten)
```

## Ingress Configuration Locations

### Terraform (`terraform-infra/ingress.tf`)

Manages **infrastructure-level** ingress rules:

1. **NGINX Ingress Controller** - Cluster-wide installation
2. **Keycloak** - `keycloak.helios` (global, shared by all environments)
3. **RabbitMQ Management UI**
   - Staging: `overflow-rabbit-staging.helios`
   - Production: `overflow-rabbit.helios`
4. **Typesense Dashboard & API**
   - Staging: `overflow-typesense-staging.helios`
   - Staging API: `overflow-typesense-api-staging.helios`

**Why Terraform?**
- Infrastructure services are provisioned once and rarely change
- Terraform manages the entire infrastructure lifecycle
- Changes require infrastructure review and approval

### Kustomize (`k8s/overlays/{env}/ingress.yaml`)

Manages **application-level** ingress rules:

- **Staging**: `k8s/overlays/staging/ingress.yaml`
  - Host: `overflow-api-staging.helios`
  - Services: Question Service, Search Service
  
- **Production**: `k8s/overlays/production/ingress.yaml`
  - Host: `overflow-api.helios`
  - Services: Question Service, Search Service

**Why Kustomize?**
- Application routing changes frequently during development
- Per-environment customization (staging vs production)
- Deployed with application code in CI/CD pipeline
- Easier to review and test routing changes

## Service Routing Details

### Question Service

**Controller Route**: `[Route("[controller]")]` → `/questions`

**Ingress Configuration**:
```yaml
- path: /questions
  pathType: Prefix
  backend:
    service:
      name: question-svc
      port:
        number: 8080
```

**No rewrite needed** - the external path matches the internal path.

**Example**:
```
GET overflow-api-staging.helios/questions
  ↓
GET question-svc:8080/questions
```

### Search Service

**Controller Route**: `[Route("api/[controller]")]` → `/api/search`

**Ingress Configuration**:
```yaml
annotations:
  nginx.ingress.kubernetes.io/rewrite-target: /api/search$2
spec:
  rules:
    - path: /search(/|$)(.*)
      pathType: ImplementationSpecific
```

**Rewrite required** - external path `/search` must be rewritten to internal path `/api/search`.

**Example**:
```
GET overflow-api-staging.helios/search?query=protocol
  ↓ (rewrite using regex capture groups)
GET search-svc:8080/api/search?query=protocol
```

**Regex Explanation**:
- Pattern: `/search(/|$)(.*)`
  - `$1` captures: `/` or end of string
  - `$2` captures: everything after (query params, additional path)
- Rewrite: `/api/search$2`
  - Prepends `/api/search`
  - Appends captured query parameters

## Base vs Overlay Pattern

### Base Configuration (`k8s/base/{service}/`)

Contains **environment-agnostic** resources:
- `deployment.yaml` - Pod template, container specs
- `service.yaml` - ClusterIP service
- `ingress.yaml` - **NOT USED** (contains reference documentation only)

The base `ingress.yaml` files are intentionally excluded from `kustomization.yaml` and serve only as documentation.

### Overlay Configuration (`k8s/overlays/{env}/`)

Contains **environment-specific** customizations:
- `kustomization.yaml` - References base + applies customizations
- `ingress.yaml` - **ACTIVE** ingress rules for this environment

Each environment defines complete ingress rules with:
- Environment-specific hostnames
- Namespace targeting
- Path rewrite rules (where needed)

## How to Modify Ingress Rules

### Infrastructure Services (RabbitMQ, Typesense, Keycloak)

1. Edit `terraform-infra/ingress.tf`
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to deploy

### Application Services (Question, Search)

1. Edit the appropriate overlay:
   - Staging: `k8s/overlays/staging/ingress.yaml`
   - Production: `k8s/overlays/production/ingress.yaml`
2. Test locally: `kubectl kustomize k8s/overlays/staging`
3. Apply: `kubectl apply -k k8s/overlays/staging`
4. Commit and push (CI/CD will deploy)

## Testing Ingress Rules

### Port-Forward (Direct Service Access)

Bypass ingress to test the service directly:

```bash
# Port-forward to the service
kubectl port-forward -n apps-staging svc/search-svc 8080:8080

# Test the actual service endpoint
curl http://localhost:8080/api/search?query=test
```

### Ingress Testing

Test through the ingress controller:

```bash
# Add to /etc/hosts or C:\Windows\System32\drivers\etc\hosts
10.12.15.60 overflow-api-staging.helios

# Test ingress routing
curl http://overflow-api-staging.helios/search?query=test
```

### Debug Ingress

Check ingress configuration:

```bash
# View ingress details
kubectl get ingress -n apps-staging
kubectl describe ingress search-svc-ingress -n apps-staging

# Check nginx logs
kubectl logs -n ingress -l app.kubernetes.io/name=ingress-nginx
```

## Naming Conventions

### Hostnames

- **Infrastructure (Staging)**: `overflow-{service}-staging.helios`
  - Example: `overflow-rabbit-staging.helios`
  
- **Infrastructure (Production)**: `overflow-{service}.helios`
  - Example: `overflow-rabbit.helios`
  
- **Application (Staging)**: `overflow-api-staging.helios`
  
- **Application (Production)**: `overflow-api.helios`

- **Global Services**: `{service}.helios`
  - Example: `keycloak.helios`

### Ingress Resource Names

- **Terraform**: `{service}_{environment}` (snake_case for Terraform)
  - Example: `rabbitmq_staging`, `keycloak_global`
  
- **Kustomize**: `{service}-ingress` (kebab-case for Kubernetes)
  - Example: `question-svc-ingress`, `search-svc-ingress`

## Troubleshooting

### 404 Not Found

**Symptom**: Ingress returns 404 but service works via port-forward

**Cause**: Path mismatch between ingress and service

**Solution**: 
1. Check service endpoint: `kubectl port-forward svc/{service} 8080:8080`
2. Verify controller route matches ingress path
3. Ensure controller uses `[Route("[controller]")]` for simple routing

### 502 Bad Gateway

**Symptom**: Ingress returns 502

**Cause**: Service is not responding or doesn't exist

**Solution**:
1. Check service exists: `kubectl get svc -n {namespace}`
2. Check pods are running: `kubectl get pods -n {namespace}`
3. Check pod logs: `kubectl logs -n {namespace} {pod-name}`

### Changes Not Applied

**Symptom**: Updated ingress.yaml but routing hasn't changed

**Cause**: Kustomize build wasn't applied or wrong file was edited

**Solution**:
1. Verify you edited the **overlay** file, not the **base** file
2. Build and apply: `kubectl apply -k k8s/overlays/staging`
3. Verify: `kubectl get ingress -n apps-staging -o yaml`

