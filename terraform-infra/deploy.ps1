# ========================================
# DevOverflow.org Infrastructure Deployment
# ========================================
# Two-stage deployment script for Terraform + cert-manager

param(
    [string]$Email = "",
    [switch]$SkipCertManager = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DevOverflow.org Infrastructure Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if email is provided
if (-not $Email -and -not $SkipCertManager) {
    Write-Host "Error: Email is required for Let's Encrypt certificates" -ForegroundColor Red
    Write-Host "Usage: .\deploy.ps1 -Email your-email@example.com" -ForegroundColor Yellow
    exit 1
}

# Check if we're in the terraform-infra directory
if (-not (Test-Path ".\provider.tf")) {
    Write-Host "Error: This script must be run from the terraform-infra directory" -ForegroundColor Red
    exit 1
}

# Stage 1: Deploy Infrastructure
Write-Host "Stage 1: Deploying Infrastructure (Terraform)" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""

Write-Host "Running: terraform init" -ForegroundColor Yellow
terraform init

Write-Host ""
Write-Host "Running: terraform plan" -ForegroundColor Yellow
terraform plan

Write-Host ""
$confirm = Read-Host "Continue with terraform apply? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Deployment cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Applying infrastructure..." -ForegroundColor Yellow
terraform apply -auto-approve

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Error: Terraform apply failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Stage 1 Complete: Infrastructure deployed" -ForegroundColor Green
Write-Host ""

# Skip cert-manager if flag is set
if ($SkipCertManager) {
    Write-Host "Skipping cert-manager ClusterIssuers deployment" -ForegroundColor Yellow
    exit 0
}

# Stage 2: Deploy ClusterIssuers
Write-Host "Stage 2: Deploying Let's Encrypt ClusterIssuers" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Waiting for cert-manager to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "Checking cert-manager pods..." -ForegroundColor Yellow
kubectl get pods -n cert-manager

Write-Host ""
Write-Host "Waiting for cert-manager CRDs..." -ForegroundColor Yellow
$maxAttempts = 12
$attempt = 0
$crdReady = $false

while ($attempt -lt $maxAttempts -and -not $crdReady) {
    $attempt++
    Write-Host "Attempt $attempt/$maxAttempts..." -ForegroundColor Gray
    
    $result = kubectl wait --for condition=established --timeout=5s crd/clusterissuers.cert-manager.io 2>&1
    if ($LASTEXITCODE -eq 0) {
        $crdReady = $true
        Write-Host "✅ ClusterIssuer CRD is ready" -ForegroundColor Green
    } else {
        Start-Sleep -Seconds 5
    }
}

if (-not $crdReady) {
    Write-Host ""
    Write-Host "Error: ClusterIssuer CRD not ready after $($maxAttempts * 5) seconds" -ForegroundColor Red
    Write-Host "Check cert-manager logs: kubectl logs -n cert-manager -l app=cert-manager" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Deploying ClusterIssuers with email: $Email" -ForegroundColor Yellow

# Read the template file
$clusterIssuerTemplate = Get-Content "..\k8s\cert-manager\clusterissuers.yaml" -Raw

# Replace the email placeholder
$clusterIssuerYaml = $clusterIssuerTemplate -replace '\$\{LETSENCRYPT_EMAIL\}', $Email

# Apply via kubectl
$clusterIssuerYaml | kubectl apply -f -

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Error: Failed to create ClusterIssuers" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Waiting for ClusterIssuers to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host ""
kubectl get clusterissuer

Write-Host ""
Write-Host "✅ Stage 2 Complete: ClusterIssuers deployed" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Infrastructure deployed (Terraform)" -ForegroundColor Green
Write-Host "✅ cert-manager installed" -ForegroundColor Green
Write-Host "✅ ClusterIssuers created" -ForegroundColor Green
Write-Host "✅ Cloudflare DDNS running" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Deploy application ingresses:" -ForegroundColor White
Write-Host "   kubectl apply -k ..\k8s\overlays\production" -ForegroundColor Gray
Write-Host "   kubectl apply -k ..\k8s\overlays\staging" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Check certificates (wait 2-5 minutes):" -ForegroundColor White
Write-Host "   kubectl get certificate -A" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Verify DDNS is updating DNS:" -ForegroundColor White
Write-Host "   kubectl logs -n kube-system -l app=cloudflare-ddns" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Test your domains:" -ForegroundColor White
Write-Host "   https://devoverflow.org" -ForegroundColor Gray
Write-Host "   https://staging.devoverflow.org" -ForegroundColor Gray
Write-Host "   https://keycloak.devoverflow.org" -ForegroundColor Gray
Write-Host "   https://keycloak-staging.devoverflow.org" -ForegroundColor Gray
Write-Host ""
Write-Host "Deployment complete! 🚀" -ForegroundColor Green

