# SLAM-Share Client Container Build Script - PowerShell
# Builds the client container from our successful base image

$ErrorActionPreference = "Stop"

$IMAGE_NAME = "slam-share-client"
$IMAGE_TAG = "latest"
$DOCKERFILE = "Dockerfile.client"

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "SLAM-Share Client Container Build" -ForegroundColor Cyan
Write-Host "Building: $IMAGE_NAME`:$IMAGE_TAG" -ForegroundColor Cyan
Write-Host "Dockerfile: docker/$DOCKERFILE" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

try {
    # Check if base image exists
    Write-Host "Checking for base image (slam-share:latest)..." -ForegroundColor Yellow
    $baseImageExists = docker images slam-share:latest --format "{{.Repository}}:{{.Tag}}" 2>$null
    if (-not $baseImageExists) {
        throw "Base image 'slam-share:latest' not found. Please run .\docker\build.ps1 first."
    }
    Write-Host "✅ Base image found: $baseImageExists" -ForegroundColor Green

    # Check if Dockerfile exists
    if (-not (Test-Path "docker\$DOCKERFILE")) {
        throw "docker\$DOCKERFILE not found in current directory: $(Get-Location)"
    }
    Write-Host "✅ docker\$DOCKERFILE found" -ForegroundColor Green

    # Display system info
    Write-Host "`nBuild Environment:" -ForegroundColor Yellow
    Write-Host "- OS: $(Get-ComputerInfo | Select-Object -ExpandProperty WindowsProductName)" -ForegroundColor Gray
    Write-Host "- PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "- Docker: $(docker --version)" -ForegroundColor Gray

    # Build the client image
    Write-Host "`nBuilding Docker image: $IMAGE_NAME`:$IMAGE_TAG" -ForegroundColor Yellow
    Write-Host "Using Dockerfile: docker\$DOCKERFILE" -ForegroundColor Gray

    $buildArgs = @(
        "build",
        "-f", "docker\$DOCKERFILE",
        "-t", "$IMAGE_NAME`:$IMAGE_TAG",
        "--progress=plain",
        "."
    )

    Write-Host "`nExecuting: docker $($buildArgs -join ' ')" -ForegroundColor Gray
    & docker @buildArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n=================================================" -ForegroundColor Green
        Write-Host "✅ SUCCESS: Client container built!" -ForegroundColor Green
        Write-Host "=================================================" -ForegroundColor Green
        Write-Host "Image: $IMAGE_NAME`:$IMAGE_TAG" -ForegroundColor White
        Write-Host "Server Connection: slam-server:6767" -ForegroundColor White
        Write-Host "Configuration: /slam-share-client/config/" -ForegroundColor White
        Write-Host ""
        Write-Host "To run the client:" -ForegroundColor Yellow
        Write-Host "docker run --network slam-network --name slam-client $IMAGE_NAME`:$IMAGE_TAG" -ForegroundColor White
        Write-Host ""
        Write-Host "To test client-server communication:" -ForegroundColor Yellow
        Write-Host ".\\docker\\test-client-server.ps1" -ForegroundColor White
        Write-Host ""
    }
    else {
        throw "Docker build failed with exit code: $LASTEXITCODE"
    }
}
catch {
    Write-Host "`n=================================================" -ForegroundColor Red
    Write-Host "❌ ERROR: Client build failed!" -ForegroundColor Red
    Write-Host "=================================================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Ensure base image slam-share:latest exists" -ForegroundColor Gray
    Write-Host "2. Check Docker Desktop is running" -ForegroundColor Gray
    Write-Host "3. Verify sufficient disk space" -ForegroundColor Gray
    exit 1
}