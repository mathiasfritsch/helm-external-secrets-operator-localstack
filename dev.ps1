# Helper-Skript für gängige Entwicklungsaufgaben

param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateSet('build', 'deploy', 'test', 'logs', 'shell', 'restart', 'clean', 'status', 'port-forward')]
    [string]$Command,
    
    [Parameter(Mandatory=$false)]
    [string]$Namespace = 'default',
    
    [Parameter(Mandatory=$false)]
    [string]$Port = '8080'
)

$ErrorActionPreference = "Stop"
$ReleaseName = "catalog-api"
$AppLabel = "app.kubernetes.io/name=catalog-api"

function Build-Image {
    Write-Host "Building Docker image..." -ForegroundColor Cyan
    Push-Location "$PSScriptRoot\CatalogApi"
    try {
        docker build -t catalog-api:latest -f CatalogApi/Dockerfile .
        Write-Host "✓ Image built successfully" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}

function Deploy-App {
    Write-Host "Deploying application..." -ForegroundColor Cyan
    & "$PSScriptRoot\deploy.ps1" -Namespace $Namespace
}

function Test-App {
    Write-Host "Testing application endpoints..." -ForegroundColor Cyan
    
    $podName = kubectl get pods -n $Namespace -l $AppLabel -o jsonpath="{.items[0].metadata.name}" 2>$null
    
    if (-not $podName) {
        Write-Host "✗ No pods found" -ForegroundColor Red
        return
    }
    
    Write-Host "`nPod Status:" -ForegroundColor Yellow
    kubectl get pod $podName -n $Namespace
    
    Write-Host "`nTesting via port-forward..." -ForegroundColor Yellow
    $job = Start-Job -ScriptBlock {
        param($ns, $pod, $port)
        kubectl port-forward -n $ns pod/$pod "${port}:8080"
    } -ArgumentList $Namespace, $podName, $Port
    
    Start-Sleep -Seconds 3
    
    try {
        Write-Host "`nGET /products:" -ForegroundColor Yellow
        Invoke-WebRequest -Uri "http://localhost:$Port/products" -UseBasicParsing | Select-Object StatusCode, Content
        
        Write-Host "`nGET /products/config:" -ForegroundColor Yellow
        Invoke-WebRequest -Uri "http://localhost:$Port/products/config" -UseBasicParsing | Select-Object StatusCode, Content
        
        Write-Host "`nGET /secrets/check:" -ForegroundColor Yellow
        Invoke-WebRequest -Uri "http://localhost:$Port/secrets/check" -UseBasicParsing | Select-Object StatusCode, Content
    }
    catch {
        Write-Host "✗ Test failed: $_" -ForegroundColor Red
    }
    finally {
        Stop-Job $job
        Remove-Job $job
    }
}

function Show-Logs {
    Write-Host "Showing logs..." -ForegroundColor Cyan
    kubectl logs -n $Namespace -l $AppLabel --tail=100 -f
}

function Open-Shell {
    Write-Host "Opening shell in pod..." -ForegroundColor Cyan
    $podName = kubectl get pods -n $Namespace -l $AppLabel -o jsonpath="{.items[0].metadata.name}"
    
    if ($podName) {
        Write-Host "Connecting to pod: $podName" -ForegroundColor Yellow
        kubectl exec -it -n $Namespace $podName -- /bin/bash
    }
    else {
        Write-Host "✗ No pods found" -ForegroundColor Red
    }
}

function Restart-App {
    Write-Host "Restarting deployment..." -ForegroundColor Cyan
    kubectl rollout restart deployment/$ReleaseName -n $Namespace
    kubectl rollout status deployment/$ReleaseName -n $Namespace
    Write-Host "✓ Deployment restarted" -ForegroundColor Green
}

function Clean-All {
    Write-Host "Cleaning up..." -ForegroundColor Cyan
    & "$PSScriptRoot\deploy.ps1" -Uninstall -Namespace $Namespace
}

function Show-Status {
    Write-Host "=== Application Status ===" -ForegroundColor Cyan
    
    Write-Host "`nDeployment:" -ForegroundColor Yellow
    kubectl get deployment $ReleaseName -n $Namespace 2>$null
    
    Write-Host "`nPods:" -ForegroundColor Yellow
    kubectl get pods -n $Namespace -l $AppLabel
    
    Write-Host "`nService:" -ForegroundColor Yellow
    kubectl get svc $ReleaseName -n $Namespace 2>$null
    
    Write-Host "`nSecret:" -ForegroundColor Yellow
    kubectl get secret my-app-credentials -n $Namespace 2>$null
    
    Write-Host "`nRecent Events:" -ForegroundColor Yellow
    kubectl get events -n $Namespace --sort-by='.lastTimestamp' | Select-Object -Last 10
}

function Start-PortForward {
    Write-Host "Starting port-forward on port $Port..." -ForegroundColor Cyan
    Write-Host "Access the application at: http://localhost:$Port" -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
    kubectl port-forward -n $Namespace svc/$ReleaseName "${Port}:80"
}

# Command Router
switch ($Command) {
    'build'        { Build-Image }
    'deploy'       { Deploy-App }
    'test'         { Test-App }
    'logs'         { Show-Logs }
    'shell'        { Open-Shell }
    'restart'      { Restart-App }
    'clean'        { Clean-All }
    'status'       { Show-Status }
    'port-forward' { Start-PortForward }
}

