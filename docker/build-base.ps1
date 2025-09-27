# SLAM-Share Base Image Build Script - PowerShell
# Step 1: Ubuntu 18.04 + Essential Build Tools
# For Windows Lambda Machine

# Enable strict error handling
$ErrorActionPreference = "Stop"

# Configuration
$IMAGE_NAME = "slam-share-base"
$IMAGE_TAG = "step1-ubuntu18.04"
$DOCKERFILE = "Dockerfile.base"

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "SLAM-Share Docker Build - Step 1" -ForegroundColor Cyan
Write-Host "Building base image with Ubuntu 18.04 + build tools" -ForegroundColor Cyan
Write-Host "Windows Lambda Machine with NVIDIA GPU" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

try {
    # Check if Docker is running
    Write-Host "Checking Docker status..." -ForegroundColor Yellow
    $dockerInfo = docker info 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker is not running. Please start Docker Desktop first."
    }
    Write-Host "✅ Docker is running" -ForegroundColor Green

    # Check if Dockerfile exists
    if (-not (Test-Path $DOCKERFILE)) {
        throw "$DOCKERFILE not found in current directory: $(Get-Location)"
    }
    Write-Host "✅ $DOCKERFILE found" -ForegroundColor Green

    # Display system info
    Write-Host "`nBuild Environment:" -ForegroundColor Yellow
    Write-Host "- OS: $(Get-ComputerInfo | Select-Object -ExpandProperty WindowsProductName)" -ForegroundColor Gray
    Write-Host "- PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "- Docker: $(docker --version)" -ForegroundColor Gray

    # Build the image
    Write-Host "`nBuilding Docker image: $IMAGE_NAME`:$IMAGE_TAG" -ForegroundColor Yellow
    Write-Host "Using Dockerfile: $DOCKERFILE" -ForegroundColor Gray

    $buildArgs = @(
        "build",
        "-f", $DOCKERFILE,
        "-t", "$IMAGE_NAME`:$IMAGE_TAG",
        "--progress=plain",
        "."
    )

    Write-Host "`nExecuting: docker $($buildArgs -join ' ')" -ForegroundColor Gray
    & docker @buildArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n=================================================" -ForegroundColor Green
        Write-Host "✅ SUCCESS: Base image built successfully!" -ForegroundColor Green
        Write-Host "=================================================" -ForegroundColor Green
        Write-Host "Image: $IMAGE_NAME`:$IMAGE_TAG" -ForegroundColor White
        Write-Host ""
        Write-Host "To test the image, run:" -ForegroundColor Yellow
        Write-Host "docker run -it --rm $IMAGE_NAME`:$IMAGE_TAG" -ForegroundColor White
        Write-Host ""
        Write-Host "To validate build environment:" -ForegroundColor Yellow
        Write-Host "docker run --rm $IMAGE_NAME`:$IMAGE_TAG bash -c 'cmake --version && g++ --version'" -ForegroundColor White
        Write-Host ""
        Write-Host "Next Step: Ready for Step 2 (C++11 + OpenCV)" -ForegroundColor Cyan
    }
    else {
        throw "Docker build failed with exit code: $LASTEXITCODE"
    }
}
catch {
    Write-Host "`n=================================================" -ForegroundColor Red
    Write-Host "❌ ERROR: Build failed!" -ForegroundColor Red
    Write-Host "=================================================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Ensure Docker Desktop is running" -ForegroundColor Gray
    Write-Host "2. Check if you're in the correct directory (should contain $DOCKERFILE)" -ForegroundColor Gray
    Write-Host "3. Verify Windows Lambda Machine has sufficient disk space" -ForegroundColor Gray
    Write-Host "4. Check Docker daemon logs if issue persists" -ForegroundColor Gray
    exit 1
}