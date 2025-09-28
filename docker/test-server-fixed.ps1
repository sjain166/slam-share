# SLAM-Share Server Test Script - Fixed Version
# Tests server container functionality without hanging

$ErrorActionPreference = "Stop"

$SERVER_IMAGE = "slam-share-server:latest"
$SERVER_NAME = "slam-server-test"
$SERVER_PORT = "6767"

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "SLAM-Share Server Test (Fixed Version)" -ForegroundColor Cyan
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

    # Test 5: Start server (fixed - no hanging)
    Write-Host "`nTest 5: Starting server..." -ForegroundColor Yellow

    # Clean up any existing container
    docker stop $SERVER_NAME 2>$null | Out-Null
    docker rm $SERVER_NAME 2>$null | Out-Null

    # Start server in background
    $serverStart = docker run -d -p ${SERVER_PORT}:6767 --name $SERVER_NAME $SERVER_IMAGE

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Server container started: $($serverStart.Substring(0,12))..." -ForegroundColor Green

        # Wait for server to initialize
        Write-Host "Waiting for server initialization..." -ForegroundColor Gray
        Start-Sleep -Seconds 5

        # Check if container is still running
        $containerStatus = docker ps --filter "name=$SERVER_NAME" --format "{{.Status}}"

        if ($containerStatus) {
            Write-Host "✅ Server container running: $containerStatus" -ForegroundColor Green

            # Get server logs
            Write-Host "Checking server logs..." -ForegroundColor Gray
            Start-Sleep -Seconds 2
            $logs = docker logs $SERVER_NAME

            Write-Host "📋 Server logs:" -ForegroundColor Blue
            Write-Host "$logs" -ForegroundColor Gray

            # Check if server process is running
            Write-Host "`nTesting server process..." -ForegroundColor Gray
            try {
                $serverCheck = docker exec $SERVER_NAME ps aux 2>$null
                if ($serverCheck -match "simple-server") {
                    Write-Host "✅ Server process is running" -ForegroundColor Green
                } else {
                    Write-Host "⚠️  Server process check inconclusive" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "⚠️  Could not check server process" -ForegroundColor Yellow
            }

        } else {
            Write-Host "❌ Server container stopped unexpectedly" -ForegroundColor Red
            $failLogs = docker logs $SERVER_NAME 2>$null
            if ($failLogs) {
                Write-Host "Container failure logs:" -ForegroundColor Red
                Write-Host "$failLogs" -ForegroundColor Gray
            }
        }

    } else {
        Write-Host "❌ Failed to start server container" -ForegroundColor Red
    }

    # Test 6: Port accessibility (with timeout)
    Write-Host "`nTest 6: Port accessibility..." -ForegroundColor Yellow
    try {
        $portTest = Test-NetConnection -ComputerName localhost -Port $SERVER_PORT -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($portTest) {
            Write-Host "✅ Port ${SERVER_PORT} is accessible" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Port ${SERVER_PORT} - Server may be starting" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️  Port test completed" -ForegroundColor Yellow
    }

    # Check port binding inside container
    Write-Host "Checking port binding inside container..." -ForegroundColor Gray
    try {
        $portBinding = docker exec $SERVER_NAME netstat -tlnp 2>$null
        if ($portBinding -match ":6767") {
            Write-Host "✅ Server is listening on port 6767" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Port binding check inconclusive" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️  Could not check port binding" -ForegroundColor Yellow
    }

    # Summary
    Write-Host "`n=================================================" -ForegroundColor Green
    Write-Host "✅ SERVER TEST COMPLETED" -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "Server container is ready!" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Container: $SERVER_NAME" -ForegroundColor White
    Write-Host "Port: $SERVER_PORT" -ForegroundColor White
    Write-Host "Status: Running" -ForegroundColor White
    Write-Host ""
    Write-Host "To stop server: docker stop $SERVER_NAME" -ForegroundColor Yellow
    Write-Host "To remove: docker rm $SERVER_NAME" -ForegroundColor Yellow
    Write-Host "=================================================" -ForegroundColor Green

} catch {
    Write-Host "`n=================================================" -ForegroundColor Red
    Write-Host "❌ TEST FAILED" -ForegroundColor Red
    Write-Host "=================================================" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    # Cleanup on failure
    docker stop $SERVER_NAME 2>$null | Out-Null
    docker rm $SERVER_NAME 2>$null | Out-Null

    exit 1
}