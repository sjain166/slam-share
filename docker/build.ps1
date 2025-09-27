# SLAM-Share Incremental Build Script - PowerShell
# Incremental Dependencies: Step 1 (Base) + Step 2 (OpenCV) + Step 3 (Eigen3) + ...
# For Windows Lambda Machine with NVIDIA GPU

# Enable strict error handling
$ErrorActionPreference = "Stop"

# Configuration
$IMAGE_NAME = "slam-share"
$IMAGE_TAG = "latest"
$DOCKERFILE = "Dockerfile.base"

# Current step info
$CURRENT_STEP = "Complete SLAM-Share Build: Dependencies + System"
$CURRENT_DEPENDENCIES = "Ubuntu 18.04, Build Tools, OpenCV 3.2, Eigen3 3.3+, Pangolin v0.6, Boost 1.65+, SLAM-Share System"

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "SLAM-Share Docker Incremental Build" -ForegroundColor Cyan
Write-Host "Current: $CURRENT_STEP" -ForegroundColor Cyan
Write-Host "Dependencies: $CURRENT_DEPENDENCIES" -ForegroundColor Cyan
Write-Host "Windows Lambda Machine with NVIDIA GPU" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

try {
    # Check if Docker is running
    Write-Host "Checking Docker status..." -ForegroundColor Yellow
    $dockerInfo = & docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker error output: $dockerInfo" -ForegroundColor Red
        throw "Docker is not running or not accessible. Please start Docker Desktop first."
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
        Write-Host "✅ SUCCESS: Incremental build completed!" -ForegroundColor Green
        Write-Host "=================================================" -ForegroundColor Green
        Write-Host "Image: $IMAGE_NAME`:$IMAGE_TAG" -ForegroundColor White
        Write-Host "Includes: $CURRENT_DEPENDENCIES" -ForegroundColor White
        Write-Host ""
        Write-Host "To test the image:" -ForegroundColor Yellow
        Write-Host ".\docker\test.ps1" -ForegroundColor White
        Write-Host ""
        Write-Host "To run interactively:" -ForegroundColor Yellow
        Write-Host "docker run -it --rm $IMAGE_NAME`:$IMAGE_TAG" -ForegroundColor White
        Write-Host ""
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