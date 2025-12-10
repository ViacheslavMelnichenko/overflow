#!/bin/bash
# Kubernetes Resource Cleanup Script
# Removes old/unused resources like secrets, configmaps, and replicasets
# Usage: ./cleanup-k8s-resources.sh <namespace> [--dry-run]

set -eo pipefail

NAMESPACE=$1
DRY_RUN=${2:-""}

if [ -z "$NAMESPACE" ]; then
    echo "❌ Error: Namespace is required"
    echo "Usage: $0 <namespace> [--dry-run]"
    exit 1
fi

echo "🧹 Kubernetes Resource Cleanup for namespace: $NAMESPACE"
echo "================================================"

if [ "$DRY_RUN" = "--dry-run" ]; then
    echo "🔍 DRY RUN MODE - No resources will be deleted"
    echo ""
fi

# Function to delete resources
delete_resource() {
    local resource_type=$1
    local resource_name=$2
    
    if [ "$DRY_RUN" = "--dry-run" ]; then
        echo "  [DRY-RUN] Would delete $resource_type: $resource_name"
    else
        kubectl delete $resource_type $resource_name -n $NAMESPACE
        echo "  ✅ Deleted $resource_type: $resource_name"
    fi
}

# ============================================================================
# 1. Clean up OLD REPLICASETS (keep last 3)
# ============================================================================
echo ""
echo "📦 Cleaning up old ReplicaSets..."
echo "  Keeping latest 3 per deployment"

DEPLOYMENTS=$(kubectl get deployments -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')

if [ -z "$DEPLOYMENTS" ]; then
    echo "  ⚠️  No deployments found - checking for orphaned replicasets"
    
    # Clean up ALL replicasets with 0 replicas when no deployments exist
    ALL_ORPHANED_RS=$(kubectl get rs -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.replicas}{"\n"}{end}' | awk '$2 == 0 {print $1}')
    
    if [ -z "$ALL_ORPHANED_RS" ]; then
        echo "  ℹ️  No orphaned replicasets to clean"
    else
        echo "  Found orphaned replicasets (no parent deployment):"
        for rs in $ALL_ORPHANED_RS; do
            delete_resource "replicaset" "$rs"
        done
    fi
else
    for deployment in $DEPLOYMENTS; do
        echo "  Checking deployment: $deployment"
        
        # Get all replicasets for this deployment, sorted by creation time, skip the latest 3
        OLD_RS=$(kubectl get rs -n $NAMESPACE \
            -l "app=$deployment" \
            --sort-by=.metadata.creationTimestamp \
            -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.replicas}{"\n"}{end}' \
            | awk '$2 == 0 {print $1}' \
            | head -n -3)
        
        if [ -z "$OLD_RS" ]; then
            echo "    ℹ️  No old replicasets to clean"
        else
            for rs in $OLD_RS; do
                delete_resource "replicaset" "$rs"
            done
        fi
    done
    
    # Also check for any orphaned replicasets that don't match known deployments
    echo ""
    echo "  Checking for orphaned replicasets without parent deployments..."
    ALL_RS=$(kubectl get rs -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.replicas}{"\n"}{end}' | awk '$2 == 0 {print $1}')
    
    ORPHANED_RS_COUNT=0
    for rs in $ALL_RS; do
        # Extract deployment name from replicaset name (format: deployment-name-hash)
        RS_BASE=$(echo $rs | sed 's/-[a-z0-9]\{8,10\}$//')
        
        # Check if this deployment exists
        if ! echo "$DEPLOYMENTS" | grep -q "^$RS_BASE$"; then
            echo "  ⚠️  Orphaned replicaset found: $rs (parent deployment '$RS_BASE' doesn't exist)"
            delete_resource "replicaset" "$rs"
            ORPHANED_RS_COUNT=$((ORPHANED_RS_COUNT + 1))
        fi
    done
    
    if [ $ORPHANED_RS_COUNT -eq 0 ]; then
        echo "  ℹ️  No orphaned replicasets found"
    fi
fi

# ============================================================================
# 2. Clean up ORPHANED SECRETS (not referenced by any pod/deployment)
# ============================================================================
echo ""
echo "🔐 Checking for orphaned secrets..."
echo "  (Secrets not referenced by any pods or deployments)"

# Get all secrets (excluding system secrets)
ALL_SECRETS=$(kubectl get secrets -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -v "^default-token" | grep -v "^ghcr-pull-secret$" || true)

if [ -z "$ALL_SECRETS" ]; then
    echo "  ℹ️  No secrets found in namespace"
else
    # Get all secrets referenced by pods and deployments
    USED_SECRETS=$(kubectl get pods,deployments -n $NAMESPACE -o jsonpath='{range .items[*]}{range .spec.containers[*]}{range .env[*]}{.valueFrom.secretKeyRef.name}{"\n"}{end}{end}{end}' 2>/dev/null | sort -u | grep -v "^$" || true)

    # Also get secrets used in volumes
    USED_SECRETS_VOLUMES=$(kubectl get pods,deployments -n $NAMESPACE -o jsonpath='{range .items[*]}{range .spec.volumes[*]}{.secret.secretName}{"\n"}{end}{end}' 2>/dev/null | sort -u | grep -v "^$" || true)

    # Combine used secrets
    ALL_USED_SECRETS=$(echo -e "$USED_SECRETS\n$USED_SECRETS_VOLUMES" | sort -u)

    # Protected secrets that should never be deleted
    PROTECTED_SECRETS="ghcr-pull-secret app-secrets webapp-secrets"

    ORPHANED_COUNT=0
    for secret in $ALL_SECRETS; do
        # Skip empty lines
        if [ -z "$secret" ]; then
            continue
        fi
        
        # Skip protected secrets
        if echo "$PROTECTED_SECRETS" | grep -q "$secret"; then
            continue
        fi
        
        # Check if secret is used
        if ! echo "$ALL_USED_SECRETS" | grep -q "^$secret$"; then
            echo "  ⚠️  Orphaned secret found: $secret"
            
            # Get age of secret
            AGE=$(kubectl get secret $secret -n $NAMESPACE -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null || echo "")
            
            if [ -z "$AGE" ]; then
                echo "      Could not determine age, skipping..."
                continue
            fi
            
            echo "      Created: $AGE"
            
            # Only delete if older than 7 days
            CREATED_TIMESTAMP=$(date -d "$AGE" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$AGE" +%s 2>/dev/null || echo "0")
            NOW=$(date +%s)
            AGE_DAYS=$(( ($NOW - $CREATED_TIMESTAMP) / 86400 ))
            
            if [ $AGE_DAYS -gt 7 ]; then
                echo "      Age: $AGE_DAYS days (> 7 days) - eligible for deletion"
                delete_resource "secret" "$secret"
                ORPHANED_COUNT=$((ORPHANED_COUNT + 1))
            else
                echo "      Age: $AGE_DAYS days (< 7 days) - keeping for rollback"
            fi
        fi
    done

    if [ $ORPHANED_COUNT -eq 0 ]; then
        echo "  ℹ️  No orphaned secrets to clean"
    fi
fi

# ============================================================================
# 3. Clean up OLD CONFIGMAPS (generated by kustomize with hash suffixes)
# ============================================================================
echo ""
echo "📝 Cleaning up old ConfigMaps..."
echo "  (Keeping currently used + last 2 versions)"

# Get all configmaps with hash suffixes (generated by kustomize)
CONFIGMAP_BASES=$(kubectl get configmaps -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -E '.*-[a-z0-9]{10}$' | sed 's/-[a-z0-9]\{10\}$//' | sort -u || true)

if [ -z "$CONFIGMAP_BASES" ]; then
    echo "  ℹ️  No kustomize-generated configmaps found"
else
    for base in $CONFIGMAP_BASES; do
        echo "  Checking ConfigMap family: $base-*"
        
        # Get all versions of this configmap
        ALL_VERSIONS=$(kubectl get configmaps -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep "^$base-" | sort || true)
        
        # Get currently used version
        USED_VERSION=$(kubectl get deployments,pods -n $NAMESPACE -o jsonpath='{range .items[*]}{range .spec.containers[*]}{range .env[*]}{.valueFrom.configMapKeyRef.name}{"\n"}{end}{end}{end}' 2>/dev/null | grep "^$base-" | sort -u || true)
        
        # Keep current + last 2 versions
        KEEP_VERSIONS=$(echo "$ALL_VERSIONS" | tail -n 3)
        
        for version in $ALL_VERSIONS; do
            if [ -z "$version" ]; then
                continue
            fi
            
            if ! echo "$KEEP_VERSIONS" | grep -q "^$version$" && ! echo "$USED_VERSION" | grep -q "^$version$"; then
                delete_resource "configmap" "$version"
            fi
        done
    done
fi

# ============================================================================
# 4. Clean up FAILED PODS
# ============================================================================
echo ""
echo "🗑️  Cleaning up failed pods..."

FAILED_PODS=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Failed -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

if [ -z "$FAILED_PODS" ]; then
    echo "  ℹ️  No failed pods to clean"
else
    for pod in $FAILED_PODS; do
        if [ -n "$pod" ]; then
            delete_resource "pod" "$pod"
        fi
    done
fi

# ============================================================================
# 5. Clean up COMPLETED JOBS (older than 24 hours)
# ============================================================================
echo ""
echo "✅ Cleaning up old completed jobs..."

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "  ⚠️  jq not found, skipping job cleanup"
else
    COMPLETED_JOBS=$(kubectl get jobs -n $NAMESPACE --field-selector=status.successful=1 -o json 2>/dev/null | \
        jq -r '.items[] | select((.status.completionTime | fromdateiso8601) < (now - 86400)) | .metadata.name' 2>/dev/null || true)

    if [ -z "$COMPLETED_JOBS" ]; then
        echo "  ℹ️  No old completed jobs to clean"
    else
        for job in $COMPLETED_JOBS; do
            if [ -n "$job" ]; then
                delete_resource "job" "$job"
            fi
        done
    fi
fi

# ============================================================================
# 6. Clean up ORPHANED SERVICES (without endpoints/pods)
# ============================================================================
echo ""
echo "🌐 Checking for orphaned services..."

ALL_SERVICES=$(kubectl get services -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

if [ -z "$ALL_SERVICES" ]; then
    echo "  ℹ️  No services found in namespace"
else
    ORPHANED_SVC_COUNT=0
    for svc in $ALL_SERVICES; do
        # Skip empty lines
        if [ -z "$svc" ]; then
            continue
        fi
        
        # Skip kubernetes service
        if [ "$svc" = "kubernetes" ]; then
            continue
        fi
        
        # Check if service has endpoints (actual pods backing it)
        ENDPOINTS=$(kubectl get endpoints $svc -n $NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
        
        if [ -z "$ENDPOINTS" ]; then
            # Service has no endpoints - check if it's been like this for a while
            CREATION_TIME=$(kubectl get service $svc -n $NAMESPACE -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null || echo "")
            
            if [ -n "$CREATION_TIME" ]; then
                CREATED_TIMESTAMP=$(date -d "$CREATION_TIME" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CREATION_TIME" +%s 2>/dev/null || echo "0")
                NOW=$(date +%s)
                AGE_MINUTES=$(( ($NOW - $CREATED_TIMESTAMP) / 60 ))
                
                # Only delete services without endpoints that are older than 30 minutes
                # This gives new deployments time to start up
                if [ $AGE_MINUTES -gt 30 ]; then
                    echo "  ⚠️  Orphaned service found: $svc (no endpoints for $AGE_MINUTES minutes)"
                    delete_resource "service" "$svc"
                    ORPHANED_SVC_COUNT=$((ORPHANED_SVC_COUNT + 1))
                else
                    echo "  ℹ️  Service $svc has no endpoints but is only $AGE_MINUTES minutes old (keeping)"
                fi
            fi
        fi
    done

    if [ $ORPHANED_SVC_COUNT -eq 0 ]; then
        echo "  ℹ️  No orphaned services found"
    fi
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "================================================"
echo "✨ Cleanup complete!"
echo ""

if [ "$DRY_RUN" = "--dry-run" ]; then
    echo "ℹ️  This was a DRY RUN - no resources were actually deleted"
    echo "   Run without --dry-run to perform actual cleanup"
fi

