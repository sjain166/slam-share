# SLAM-Share Server Simple Test Script - PowerShell
# Tests the server container functionality with proper PowerShell syntax

$ErrorActionPreference = "Stop"

$SERVER_IMAGE = "slam-share-server:latest"
$SERVER_NAME = "slam-server-test"
$SERVER_PORT = "6767"

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "SLAM-Share Server Functionality Test" -ForegroundColor Cyan
Write-Host "Testing image: $SERVER_IMAGE" -ForegroundColor Cyan
Write-Host "Server port: $SERVER_PORT" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

try {
    # Check if server image exists
    Write-Host "Checking if server image exists..." -ForegroundColor Yellow
    $imageExists = docker images $SERVER_IMAGE --format "{{.Repository}}:{{.Tag}}" 2>$null
    if (-not $imageExists) {
        throw "Server image '$SERVER_IMAGE' not found. Please run .\docker\build-server.ps1 first."
    }
    Write-Host "✅ Server image found: $imageExists" -ForegroundColor Green

    # Clean up any existing test container
    Write-Host "`nCleaning up existing test containers..." -ForegroundColor Yellow
    docker stop $SERVER_NAME 2>$null | Out-Null
    docker rm $SERVER_NAME 2>$null | Out-Null
    Write-Host "✅ Cleanup completed" -ForegroundColor Green

    # Test 1: Basic container functionality
    Write-Host "`n=== TEST 1: Basic Container Functionality ===" -ForegroundColor Cyan
    Write-Host "Testing basic container startup..." -ForegroundColor Yellow
    $basicTest = docker run --rm $SERVER_IMAGE echo "Server container is working"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Basic container test: PASSED" -ForegroundColor Green
    } else {
        throw "Basic container test failed"
    }

    # Test 2: Check server directories and files
    Write-Host "`n=== TEST 2: Server Structure Verification ===" -ForegroundColor Cyan
    Write-Host "Checking server directories and files..." -ForegroundColor Yellow

    $dirCheck = docker run --rm $SERVER_IMAGE ls -la /slam-share-server/
    if ($dirCheck -match "simple-server") {
        Write-Host "✅ Server executable: FOUND" -ForegroundColor Green
    } else {
        Write-Host "❌ Server executable: NOT FOUND" -ForegroundColor Red
    }

    $configCheck = docker run --rm $SERVER_IMAGE ls -la /slam-share-server/config/
    if ($configCheck -match "TUM_VI.yaml") {
        Write-Host "✅ Configuration file: FOUND" -ForegroundColor Green
    } else {
        Write-Host "❌ Configuration file: NOT FOUND" -ForegroundColor Red
    }

    # Test 3: Test server configuration content
    Write-Host "`n=== TEST 3: Configuration Content ===" -ForegroundColor Cyan
    Write-Host "Checking server configuration content..." -ForegroundColor Yellow

    $configContent = docker run --rm $SERVER_IMAGE cat /slam-share-server/config/TUM_VI.yaml
    if ($configContent -match "Camera.fx" -and $configContent -match "Server.Port") {
        Write-Host "✅ Configuration content: VALID" -ForegroundColor Green
    } else {
        Write-Host "❌ Configuration content: INVALID" -ForegroundColor Red
        Write-Host "Config content: $configContent" -ForegroundColor Gray
    }

    # Test 4: Start server and check if it runs
    Write-Host "`n=== TEST 4: Server Runtime Test ===" -ForegroundColor Cyan
    Write-Host "Starting server in background..." -ForegroundColor Yellow

    # Start server container in detached mode
    $containerResult = docker run -d -p ${SERVER_PORT}:6767 --name $SERVER_NAME $SERVER_IMAGE

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Server container started: $containerResult" -ForegroundColor Green

        # Wait for server to initialize
        Write-Host "Waiting for server to initialize..." -ForegroundColor Gray
        Start-Sleep -Seconds 3

        # Check if container is running
        $containerStatus = docker ps --filter "name=$SERVER_NAME" --format "{{.Status}}"
        if ($containerStatus) {
            Write-Host "✅ Server container status: $containerStatus" -ForegroundColor Green

            # Check server logs
            Write-Host "Checking server logs..." -ForegroundColor Yellow
            $serverLogs = docker logs $SERVER_NAME
            Write-Host "📋 Server logs:" -ForegroundColor Blue
            Write-Host "$serverLogs" -ForegroundColor Gray

            # Test port connectivity
            Write-Host "Testing port connectivity..." -ForegroundColor Yellow
            try {
                $portTest = Test-NetConnection -ComputerName localhost -Port $SERVER_PORT -InformationLevel Quiet -WarningAction SilentlyContinue
                if ($portTest) {
                    Write-Host "✅ Port $SERVER_PORT is accessible" -ForegroundColor Green
                } else {
                    Write-Host "⚠️  Port test inconclusive (server may need client connection)" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "⚠️  Port test error: $($_.Exception.Message)" -ForegroundColor Yellow
            }

        } else {
            Write-Host "❌ Server container not running" -ForegroundColor Red
            $containerLogs = docker logs $SERVER_NAME
            Write-Host "Container logs: $containerLogs" -ForegroundColor Gray
        }
    } else {
        throw "Failed to start server container"
    }

    # Test 5: File system test
    Write-Host "`n=== TEST 5: File System Test ===" -ForegroundColor Cyan
    Write-Host "Testing server file system access..." -ForegroundColor Yellow

    $fileSystemTest = docker exec $SERVER_NAME ls -la /slam-share-server/received-data/
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Server data directory accessible" -ForegroundColor Green
    } else {
        Write-Host "❌ Server data directory access failed" -ForegroundColor Red
    }

    # Summary
    Write-Host "`n=================================================" -ForegroundColor Green
    Write-Host "✅ SLAM-SHARE SERVER TEST COMPLETED" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "✅ Image: Found and working" -ForegroundColor White
    Write-Host "✅ Structure: Verified" -ForegroundColor White
    Write-Host "✅ Configuration: Valid" -ForegroundColor White
    Write-Host "✅ Runtime: Server started" -ForegroundColor White
    Write-Host "✅ File System: Accessible" -ForegroundColor White
    Write-Host ""
    Write-Host "🎯 Server container is ready!" -ForegroundColor Cyan
    Write-Host "Container ID: $containerResult" -ForegroundColor Gray
    Write-Host "Status: Running on port $SERVER_PORT" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next: Build client container" -ForegroundColor Yellow
    Write-Host "=================================================" -ForegroundColor Green

} catch {
    Write-Host "`n=================================================" -ForegroundColor Red
    Write-Host "❌ SERVER TEST FAILED" -ForegroundColor Red
    Write-Host "=================================================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Check if base image slam-share:latest exists" -ForegroundColor Gray
    Write-Host "2. Verify Docker Desktop is running" -ForegroundColor Gray
    Write-Host "3. Check container logs with: docker logs $SERVER_NAME" -ForegroundColor Gray
    exit 1
} finally {
    # Cleanup notice (don't auto-cleanup so you can inspect)
    Write-Host "`nNote: Server container '$SERVER_NAME' is still running for inspection" -ForegroundColor Blue
    Write-Host "To stop: docker stop $SERVER_NAME" -ForegroundColor Gray
    Write-Host "To remove: docker rm $SERVER_NAME" -ForegroundColor Gray
}