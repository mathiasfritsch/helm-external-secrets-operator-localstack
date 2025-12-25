# PowerShell Deployment Script für CatalogApi

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('minikube', 'kind', 'docker-desktop')]
    [string]$K8sProvider = 'docker-desktop',
    
    [Parameter(Mandatory=$false)]
    [string]$ReleaseName = 'catalog-api',
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = 'default',
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild,
    
    [Parameter(Mandatory=$false)]
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CatalogApiDir = Join-Path $ScriptDir "CatalogApi"
$ChartDir = Join-Path $ScriptDir "CatalogApiChart"

Write-Host "=== CatalogApi Kubernetes Deployment ===" -ForegroundColor Cyan
Write-Host "Kubernetes Provider: $K8sProvider" -ForegroundColor Yellow
Write-Host "Release Name: $ReleaseName" -ForegroundColor Yellow
Write-Host "Namespace: $Namespace" -ForegroundColor Yellow
Write-Host ""

# Uninstall Mode
if ($Uninstall) {
    Write-Host "Uninstalling Helm release..." -ForegroundColor Yellow
    helm uninstall $ReleaseName -n $Namespace 2>$null
    
    Write-Host "Deleting secret..." -ForegroundColor Yellow
    kubectl delete secret my-app-credentials -n $Namespace --ignore-not-found=true
    
    Write-Host "Cleanup complete!" -ForegroundColor Green
    exit 0
}

# 1. Build Docker Image
if (-not $SkipBuild) {
    Write-Host "Step 1: Building Docker image..." -ForegroundColor Green
    Push-Location $CatalogApiDir
    try {
        docker build -t catalog-api:latest -f CatalogApi/Dockerfile .
        if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }
        Write-Host "✓ Docker image built successfully" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
} else {
    Write-Host "Step 1: Skipping Docker build" -ForegroundColor Yellow
}

# 2. Load Image into Kubernetes
Write-Host "`nStep 2: Loading image into Kubernetes..." -ForegroundColor Green
switch ($K8sProvider) {
    'minikube' {
        minikube image load catalog-api:latest
        if ($LASTEXITCODE -ne 0) { throw "Failed to load image into minikube" }
    }
    'kind' {
        kind load docker-image catalog-api:latest
        if ($LASTEXITCODE -ne 0) { throw "Failed to load image into kind" }
    }
    'docker-desktop' {
        Write-Host "Image already available in Docker Desktop" -ForegroundColor Yellow
    }
}
Write-Host "✓ Image loaded successfully" -ForegroundColor Green

# 3. Create Secret
Write-Host "`nStep 3: Creating Kubernetes secret..." -ForegroundColor Green
$secretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: my-app-credentials
  namespace: $Namespace
type: Opaque
stringData:
  username: myusername
  password: mypassword
  api-key: my-secret-api-key-12345
"@

$secretYaml | kubectl apply -f - 2>$null
if ($LASTEXITCODE -ne 0) { 
    Write-Host "✓ Secret already exists or created" -ForegroundColor Yellow
} else {
    Write-Host "✓ Secret created successfully" -ForegroundColor Green
}

# 4. Install/Upgrade Helm Chart
Write-Host "`nStep 4: Installing/Upgrading Helm chart..." -ForegroundColor Green
Push-Location $ScriptDir
try {
    # Check if release exists
    $releaseExists = helm list -n $Namespace | Select-String $ReleaseName
    
    if ($releaseExists) {
        Write-Host "Release exists, upgrading..." -ForegroundColor Yellow
        helm upgrade $ReleaseName ./CatalogApiChart -n $Namespace
    } else {
        Write-Host "Installing new release..." -ForegroundColor Yellow
        helm install $ReleaseName ./CatalogApiChart -n $Namespace
    }
    
    if ($LASTEXITCODE -ne 0) { throw "Helm install/upgrade failed" }
    Write-Host "✓ Helm chart deployed successfully" -ForegroundColor Green
}
finally {
    Pop-Location
}

# 5. Wait for deployment
Write-Host "`nStep 5: Waiting for deployment to be ready..." -ForegroundColor Green
kubectl wait --for=condition=available --timeout=60s deployment/$ReleaseName -n $Namespace
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Deployment is ready" -ForegroundColor Green
} else {
    Write-Host "⚠ Deployment may not be ready yet" -ForegroundColor Yellow
}

# 6. Show status
Write-Host "`n=== Deployment Status ===" -ForegroundColor Cyan
kubectl get pods -n $Namespace -l app.kubernetes.io/name=catalog-api
Write-Host ""
kubectl get svc -n $Namespace -l app.kubernetes.io/name=catalog-api

# 7. Test endpoints
Write-Host "`n=== Testing Application ===" -ForegroundColor Cyan
Write-Host "Setting up port-forward to test the application..." -ForegroundColor Yellow
Write-Host "Run the following command in a separate terminal:" -ForegroundColor Yellow
Write-Host "kubectl port-forward svc/$ReleaseName -n $Namespace 8080:80" -ForegroundColor White
Write-Host ""
Write-Host "Then test with:" -ForegroundColor Yellow
Write-Host "  curl http://localhost:8080/products" -ForegroundColor White
Write-Host "  curl http://localhost:8080/products/config" -ForegroundColor White
Write-Host "  curl http://localhost:8080/secrets/check" -ForegroundColor White
Write-Host ""

# 8. Show logs command
Write-Host "To view logs, run:" -ForegroundColor Yellow
Write-Host "kubectl logs -n $Namespace -l app.kubernetes.io/name=catalog-api -f" -ForegroundColor White
Write-Host ""

Write-Host "=== Deployment Complete! ===" -ForegroundColor Green

