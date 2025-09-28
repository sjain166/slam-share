# Complete Distributed SLAM System Test Script - PowerShell Version
# Tests ROS-enabled client-server SLAM communication

param(
    [switch]$Cleanup = $false
)

# Configuration
$NETWORK_NAME = "slam-ros-network"
$SERVER_NAME = "slam-server"
$CLIENT_NAME = "slam-client"
$SERVER_IMAGE = "slam-share-ros-server:latest"
$CLIENT_IMAGE = "slam-share-ros-client:latest"
$ROS_MASTER_PORT = "11311"

Write-Host "========================================" -ForegroundColor Blue
Write-Host "SLAM-Share Distributed System Test" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue

# Function to print status
function Print-Status {
    param($Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Print-Warning {
    param($Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Print-Error {
    param($Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

# Function to cleanup
function Cleanup-Containers {
    Write-Host "Cleaning up existing containers and network..." -ForegroundColor Yellow
    docker stop $SERVER_NAME 2>$null
    docker stop $CLIENT_NAME 2>$null
    docker rm $SERVER_NAME 2>$null
    docker rm $CLIENT_NAME 2>$null
    docker network rm $NETWORK_NAME 2>$null
}

if ($Cleanup) {
    Cleanup-Containers
    Write-Host "Cleanup completed." -ForegroundColor Green
    exit 0
}

try {
    # Step 1: Cleanup
    Cleanup-Containers

    # Step 2: Create network
    Write-Host "Step 1: Creating Docker network..." -ForegroundColor Blue
    docker network create $NETWORK_NAME
    if ($LASTEXITCODE -ne 0) { throw "Failed to create network" }
    Print-Status "Network '$NETWORK_NAME' created"

    # Step 3: Start ROS Master Server
    Write-Host "Step 2: Starting ROS Master Server..." -ForegroundColor Blue
    docker run -d --name $SERVER_NAME --network $NETWORK_NAME --hostname $SERVER_NAME -p "${ROS_MASTER_PORT}:${ROS_MASTER_PORT}" $SERVER_IMAGE /slam-share-ros-server/start-ros-master.sh
    if ($LASTEXITCODE -ne 0) { throw "Failed to start ROS Master server" }
    Print-Status "ROS Master server container started"

    # Step 4: Wait for ROS Master
    Write-Host "Step 3: Waiting for ROS Master..." -ForegroundColor Blue
    Start-Sleep 15

    $rosCheck = docker exec $SERVER_NAME /bin/bash -c "source /opt/ros/melodic/setup.bash && export ROS_MASTER_URI=http://localhost:11311 && rostopic list" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Print-Status "ROS Master is running"
        Write-Host "Available topics:" -ForegroundColor Blue
        Write-Host $rosCheck
    } else {
        Print-Error "ROS Master failed to start"
        Write-Host "Server logs:" -ForegroundColor Yellow
        docker logs $SERVER_NAME
        throw "ROS Master startup failed"
    }

    # Step 5: Start SLAM Server (replace ROS Master with SLAM)
    Write-Host "Step 4: Starting SLAM Server..." -ForegroundColor Blue
    docker stop $SERVER_NAME
    docker rm $SERVER_NAME

    # Create inline script for SLAM server
    $slamScript = @"
source /opt/ros/melodic/setup.bash
export ROS_MASTER_URI=http://localhost:11311
export ROS_HOSTNAME=slam-server
export ROS_PACKAGE_PATH=/slam-share/Examples/ROS/ORB_SLAM3:`$ROS_PACKAGE_PATH
export LD_LIBRARY_PATH=/opt/ros/melodic/lib:`$LD_LIBRARY_PATH
echo '=== Starting ROS Master ==='
roscore &
sleep 10
echo '=== Starting SLAM Server ==='
cd /slam-share/Examples/ROS/ORB_SLAM3
./Mono /slam-share/Vocabulary/ORBvoc.txt /slam-share-ros-server/config/Asus.yaml
"@

    docker run -d --name $SERVER_NAME --network $NETWORK_NAME --hostname $SERVER_NAME -p "${ROS_MASTER_PORT}:${ROS_MASTER_PORT}" $SERVER_IMAGE /bin/bash -c $slamScript
    if ($LASTEXITCODE -ne 0) { throw "Failed to start SLAM server" }
    Print-Status "SLAM Server container started"

    Start-Sleep 15

    # Step 6: Check SLAM Server status
    Write-Host "Step 5: Checking SLAM Server status..." -ForegroundColor Blue
    $serverStatus = docker ps --filter "name=$SERVER_NAME" --format "{{.Status}}"
    if ($serverStatus -like "*Up*") {
        Print-Status "SLAM Server container is running"
        Write-Host "Recent server logs:" -ForegroundColor Blue
        docker logs $SERVER_NAME | Select-Object -Last 10
    } else {
        Print-Error "SLAM Server container stopped"
        Write-Host "Server logs:" -ForegroundColor Yellow
        docker logs $SERVER_NAME
        throw "SLAM Server failed"
    }

    # Step 7: Start ROS Client
    Write-Host "Step 6: Starting ROS Client..." -ForegroundColor Blue
    docker run -d --name $CLIENT_NAME --network $NETWORK_NAME --hostname $CLIENT_NAME -e ROS_MASTER_URI=http://${SERVER_NAME}:${ROS_MASTER_PORT} -e ROS_HOSTNAME=$CLIENT_NAME $CLIENT_IMAGE /slam-share-ros-client/start-ros-client.sh
    if ($LASTEXITCODE -ne 0) { throw "Failed to start ROS client" }
    Print-Status "ROS Client container started"

    Start-Sleep 10

    # Step 8: Test client-server communication
    Write-Host "Step 7: Testing client-server ROS communication..." -ForegroundColor Blue
    $clientTopics = docker exec $CLIENT_NAME /bin/bash -c "source /opt/ros/melodic/setup.bash && export ROS_MASTER_URI=http://${SERVER_NAME}:${ROS_MASTER_PORT} && rostopic list" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Print-Status "Client-server ROS communication working"
        Write-Host "Topics visible from client:" -ForegroundColor Blue
        Write-Host $clientTopics
    } else {
        Print-Warning "Client-server communication issue"
        Write-Host "Client logs:" -ForegroundColor Yellow
        docker logs $CLIENT_NAME
    }

    # Step 9: Final status
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "✅ DISTRIBUTED SLAM SYSTEM TEST COMPLETE" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Blue

    Write-Host "System Status:" -ForegroundColor Blue
    Write-Host "Network: $NETWORK_NAME"
    Write-Host "Server: $SERVER_NAME (port $ROS_MASTER_PORT)"
    Write-Host "Client: $CLIENT_NAME"
    Write-Host ""

    Write-Host "Container Status:" -ForegroundColor Blue
    docker ps --filter "network=$NETWORK_NAME" --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"

    Write-Host ""
    Write-Host "Recent Server Logs:" -ForegroundColor Blue
    docker logs $SERVER_NAME | Select-Object -Last 5

    Write-Host ""
    Write-Host "Recent Client Logs:" -ForegroundColor Blue
    docker logs $CLIENT_NAME | Select-Object -Last 5

    Write-Host ""
    Write-Host "Manual Commands:" -ForegroundColor Yellow
    Write-Host "View server logs: docker logs $SERVER_NAME"
    Write-Host "View client logs:  docker logs $CLIENT_NAME"
    Write-Host "Test ROS topics:   docker exec $CLIENT_NAME rostopic list"
    Write-Host "Clean up:          .\test-distributed-slam.ps1 -Cleanup"

    Write-Host ""
    Write-Host "🚀 Distributed SLAM system is ready for testing!" -ForegroundColor Green

} catch {
    Print-Error "Test failed: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Diagnostic Information:" -ForegroundColor Yellow
    Write-Host "Server logs:" -ForegroundColor Yellow
    docker logs $SERVER_NAME 2>$null
    Write-Host ""
    Write-Host "Client logs:" -ForegroundColor Yellow
    docker logs $CLIENT_NAME 2>$null

    Write-Host ""
    Write-Host "Run cleanup: .\test-distributed-slam.ps1 -Cleanup" -ForegroundColor Yellow
    exit 1
}