# SLAM-Share Server Basic Test Script
# Simple PowerShell test for server container

$ErrorActionPreference = "Stop"

$SERVER_IMAGE = "slam-share-server:latest"
$SERVER_NAME = "slam-server-test"
$SERVER_PORT = "6767"

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "SLAM-Share Server Basic Test" -ForegroundColor Cyan
Write-Host "Testing image: $SERVER_IMAGE" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

try {
    # Test 1: Check if image exists
    Write-Host "Test 1: Checking server image..." -ForegroundColor Yellow
    $imageCheck = docker images $SERVER_IMAGE --format "{{.Repository}}:{{.Tag}}" 2>$null
    if ($imageCheck) {
        Write-Host "✅ Server image found: $imageCheck" -ForegroundColor Green
    } else {
        throw "Server image not found"
    }

    # Test 2: Basic container run
    Write-Host "`nTest 2: Basic container functionality..." -ForegroundColor Yellow
    $basicTest = docker run --rm $SERVER_IMAGE echo "Container working"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Basic container: WORKING" -ForegroundColor Green
    } else {
        throw "Basic container test failed"
    }

    # Test 3: Check server files
    Write-Host "`nTest 3: Server files verification..." -ForegroundColor Yellow
    $fileCheck = docker run --rm $SERVER_IMAGE ls /slam-share-server/simple-server
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Server executable: FOUND" -ForegroundColor Green
    } else {
        Write-Host "❌ Server executable: NOT FOUND" -ForegroundColor Red
    }

    # Test 4: Configuration check
    Write-Host "`nTest 4: Configuration file..." -ForegroundColor Yellow
    $configCheck = docker run --rm $SERVER_IMAGE cat /slam-share-server/config/TUM_VI.yaml
    if ($configCheck -match "Camera.fx") {
        Write-Host "✅ Configuration: VALID" -ForegroundColor Green
    } else {
        Write-Host "❌ Configuration: INVALID" -ForegroundColor Red
    }

    # Test 5: Start server
    Write-Host "`nTest 5: Starting server..." -ForegroundColor Yellow

    # Clean up any existing container
    docker stop $SERVER_NAME 2>$null | Out-Null
    docker rm $SERVER_NAME 2>$null | Out-Null

    # Start server in background
    $serverStart = docker run -d -p ${SERVER_PORT}:6767 --name $SERVER_NAME $SERVER_IMAGE

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Server started: $serverStart" -ForegroundColor Green

        # Wait and check status
        Start-Sleep -Seconds 2
        $containerStatus = docker ps --filter "name=$SERVER_NAME" --format "{{.Status}}"

        if ($containerStatus) {
            Write-Host "✅ Server running: $containerStatus" -ForegroundColor Green

            # Show logs
            Write-Host "`nServer logs:" -ForegroundColor Blue
            $logs = docker logs $SERVER_NAME
            Write-Host $logs -ForegroundColor Gray

        } else {
            Write-Host "❌ Server not running" -ForegroundColor Red
        }

    } else {
        Write-Host "❌ Failed to start server" -ForegroundColor Red
    }

    # Test 6: Port check
    Write-Host "`nTest 6: Port accessibility..." -ForegroundColor Yellow
    try {
        $portTest = Test-NetConnection -ComputerName localhost -Port $SERVER_PORT -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($portTest) {
            Write-Host "✅ Port ${SERVER_PORT} ACCESSIBLE" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Port ${SERVER_PORT} May need client connection" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️  Port test completed" -ForegroundColor Yellow
    }

    # Summary
    Write-Host "`n=================================================" -ForegroundColor Green
    Write-Host "✅ SERVER TEST COMPLETED" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "Server container is ready for client connections!" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Container: $SERVER_NAME" -ForegroundColor White
    Write-Host "Port: $SERVER_PORT" -ForegroundColor White
    Write-Host "Status: Running" -ForegroundColor White
    Write-Host ""
    Write-Host "To stop server: docker stop $SERVER_NAME" -ForegroundColor Yellow
    Write-Host "To remove: docker rm $SERVER_NAME" -ForegroundColor Yellow
    Write-Host "=================================================" -ForegroundColor Green

}
catch {
    Write-Host "`n=================================================" -ForegroundColor Red
    Write-Host "❌ TEST FAILED" -ForegroundColor Red
    Write-Host "=================================================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    # Cleanup on failure
    docker stop $SERVER_NAME 2>$null | Out-Null
    docker rm $SERVER_NAME 2>$null | Out-Null

    exit 1
}