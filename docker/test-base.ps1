# SLAM-Share Base Image Validation Script - PowerShell
# Test Step 1: Ubuntu 18.04 + Essential Build Tools

$ErrorActionPreference = "Stop"

$IMAGE_NAME = "slam-share-base"
$IMAGE_TAG = "step1-ubuntu18.04"
$FULL_IMAGE = "$IMAGE_NAME`:$IMAGE_TAG"

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "SLAM-Share Docker Validation - Step 1" -ForegroundColor Cyan
Write-Host "Testing base image: $FULL_IMAGE" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

try {
    # Check if image exists
    Write-Host "Checking if image exists..." -ForegroundColor Yellow
    $imageExists = docker images $FULL_IMAGE --format "{{.Repository}}:{{.Tag}}" 2>$null
    if (-not $imageExists) {
        throw "Image $FULL_IMAGE not found. Please run build-base.ps1 first."
    }
    Write-Host "✅ Image found: $imageExists" -ForegroundColor Green

    # Test 1: Basic container run
    Write-Host "`nTest 1: Basic container functionality..." -ForegroundColor Yellow
    $basicTest = docker run --rm $FULL_IMAGE echo "Container is working"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Basic container run: PASSED" -ForegroundColor Green
    } else {
        throw "Basic container run failed"
    }

    # Test 2: Ubuntu version verification
    Write-Host "`nTest 2: Ubuntu version verification..." -ForegroundColor Yellow
    $ubuntuVersion = docker run --rm $FULL_IMAGE cat /etc/os-release | Select-String "VERSION="
    Write-Host "Ubuntu version: $ubuntuVersion" -ForegroundColor Gray
    if ($ubuntuVersion -match "18.04") {
        Write-Host "✅ Ubuntu 18.04: CONFIRMED" -ForegroundColor Green
    } else {
        Write-Warning "Expected Ubuntu 18.04, got: $ubuntuVersion"
    }

    # Test 3: Build tools verification
    Write-Host "`nTest 3: Build tools verification..." -ForegroundColor Yellow

    $tools = @("cmake", "make", "gcc", "g++", "git", "python")
    foreach ($tool in $tools) {
        $version = docker run --rm $FULL_IMAGE bash -c "$tool --version 2>&1 | head -1"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $tool`: $version" -ForegroundColor Green
        } else {
            Write-Host "❌ $tool`: NOT FOUND" -ForegroundColor Red
        }
    }

    # Test 4: C++11 compilation test
    Write-Host "`nTest 4: C++11 compilation test..." -ForegroundColor Yellow
    $cppTest = docker run --rm $FULL_IMAGE bash -c 'echo "int main(){return 0;}" > test.cpp && g++ -std=c++11 test.cpp -o test && ./test && echo "C++11 compilation successful"'
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ C++11 compilation: PASSED" -ForegroundColor Green
    } else {
        Write-Host "❌ C++11 compilation: FAILED" -ForegroundColor Red
    }

    # Test 5: Working directory
    Write-Host "`nTest 5: Working directory verification..." -ForegroundColor Yellow
    $workDir = docker run --rm $FULL_IMAGE pwd
    if ($workDir -eq "/slam-share") {
        Write-Host "✅ Working directory: $workDir" -ForegroundColor Green
    } else {
        Write-Warning "Expected /slam-share, got: $workDir"
    }

    Write-Host "`n=================================================" -ForegroundColor Green
    Write-Host "✅ ALL TESTS COMPLETED" -ForegroundColor Green
    Write-Host "Base image is ready for Step 2!" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green

} catch {
    Write-Host "`n=================================================" -ForegroundColor Red
    Write-Host "❌ VALIDATION FAILED" -ForegroundColor Red
    Write-Host "=================================================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}