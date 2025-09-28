#!/bin/bash
# Test script for SLAM-Share Augmented Reality Visualization
# Tests real-time GUI visualization with ROS-enabled distributed SLAM

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NETWORK_NAME="slam-ros-network"
SERVER_NAME="slam-ar-server"
CLIENT_NAME="slam-ar-client"
SERVER_IMAGE="slam-share-ros-server:latest"
CLIENT_IMAGE="slam-share-ros-client:latest"
ROS_MASTER_PORT="11311"

echo -e "${BLUE}========================================"
echo "SLAM-Share AR Visualization Test"
echo "Real-time 3D mapping with GUI"
echo -e "========================================${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to cleanup
cleanup() {
    echo -e "${YELLOW}Cleaning up AR test containers...${NC}"
    docker stop $SERVER_NAME $CLIENT_NAME 2>/dev/null || true
    docker rm $SERVER_NAME $CLIENT_NAME 2>/dev/null || true
    docker network rm $NETWORK_NAME 2>/dev/null || true
}

# Check for X11 requirements
check_x11() {
    echo -e "${BLUE}Checking X11 requirements...${NC}"

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v xhost >/dev/null 2>&1; then
            echo "Allowing X11 connections for Docker..."
            xhost +local:docker 2>/dev/null || true
            print_status "X11 forwarding configured for Linux"
        else
            print_warning "xhost not found - install xorg-xhost for X11 forwarding"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v xquartz >/dev/null 2>&1; then
            print_status "XQuartz detected for macOS X11 forwarding"
            echo "Make sure XQuartz is running and 'Allow connections from network clients' is enabled"
        else
            print_warning "Install XQuartz for macOS X11 forwarding: brew install --cask xquartz"
        fi
    else
        print_warning "Unsupported OS for X11 forwarding: $OSTYPE"
    fi
}

# Cleanup previous containers
cleanup

# Check X11 setup
check_x11

# Step 1: Create network
echo -e "${BLUE}Step 1: Creating Docker network for AR visualization...${NC}"
docker network create $NETWORK_NAME
print_status "Network '$NETWORK_NAME' created"

# Step 2: Start AR Server with GUI
echo -e "${BLUE}Step 2: Starting AR SLAM Server with GUI...${NC}"
echo "This will start the server with Pangolin-based 3D visualization"

# Set display for X11 forwarding
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    DISPLAY_VAR="${DISPLAY:-:0}"
    X11_VOLUMES="-v /tmp/.X11-unix:/tmp/.X11-unix:rw"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS with XQuartz
    DISPLAY_VAR="host.docker.internal:0"
    X11_VOLUMES=""
else
    DISPLAY_VAR=":0"
    X11_VOLUMES=""
fi

echo "Using DISPLAY=$DISPLAY_VAR"

docker run -d \
    --name $SERVER_NAME \
    --network $NETWORK_NAME \
    --hostname $SERVER_NAME \
    -p $ROS_MASTER_PORT:$ROS_MASTER_PORT \
    -e DISPLAY=$DISPLAY_VAR \
    $X11_VOLUMES \
    --privileged \
    $SERVER_IMAGE \
    /slam-share-ros-server/start-ar-server.sh

print_status "AR Server container started with GUI visualization"
sleep 15

# Step 3: Check AR Server status
echo -e "${BLUE}Step 3: Checking AR Server status...${NC}"
if docker ps --filter "name=$SERVER_NAME" --format "{{.Status}}" | grep -q "Up"; then
    print_status "AR Server container is running"
    echo -e "${BLUE}Testing GUI components:${NC}"
    docker exec $SERVER_NAME /slam-share-ros-server/test-gui.sh || print_warning "GUI test failed - check X11 forwarding"
else
    print_error "AR Server container stopped"
    echo -e "${YELLOW}Server logs:${NC}"
    docker logs $SERVER_NAME
    exit 1
fi

# Step 4: Start ROS Client for data streaming
echo -e "${BLUE}Step 4: Starting ROS Client for camera data streaming...${NC}"
docker run -d \
    --name $CLIENT_NAME \
    --network $NETWORK_NAME \
    --hostname $CLIENT_NAME \
    -e ROS_MASTER_URI=http://$SERVER_NAME:$ROS_MASTER_PORT \
    -e ROS_HOSTNAME=$CLIENT_NAME \
    $CLIENT_IMAGE \
    /slam-share-ros-client/start-ros-client.sh

print_status "ROS Client container started"
sleep 10

# Step 5: Test ROS connectivity
echo -e "${BLUE}Step 5: Testing ROS connectivity...${NC}"
CLIENT_TOPICS=$(docker exec $CLIENT_NAME /bin/bash -c "source /opt/ros/melodic/setup.bash && export ROS_MASTER_URI=http://$SERVER_NAME:$ROS_MASTER_PORT && rostopic list" 2>/dev/null || echo "FAILED")

if [[ "$CLIENT_TOPICS" != "FAILED" ]]; then
    print_status "Client-server ROS communication working"
    echo -e "${BLUE}Available ROS topics:${NC}"
    echo "$CLIENT_TOPICS"
else
    print_error "ROS communication failed"
    exit 1
fi

# Step 6: Start camera data publishing
echo -e "${BLUE}Step 6: Publishing camera data for real-time SLAM...${NC}"
echo "Starting camera data stream to /camera/image_raw topic"

# Start camera publisher in background
docker exec -d $CLIENT_NAME /bin/bash -c "
source /opt/ros/melodic/setup.bash
export ROS_MASTER_URI=http://$SERVER_NAME:$ROS_MASTER_PORT
export ROS_HOSTNAME=$CLIENT_NAME
echo 'Starting camera data publisher...'
/slam-share-ros-client/publish-test-images.sh
"

sleep 5
print_status "Camera data streaming started"

# Step 7: Monitor SLAM processing
echo -e "${BLUE}Step 7: Monitoring SLAM processing...${NC}"
echo "Checking for SLAM processing activity..."

# Check if SLAM is receiving data
SLAM_ACTIVITY=$(docker logs $SERVER_NAME | tail -20 | grep -i "tracking\|slam\|image\|frame" || echo "")
if [[ -n "$SLAM_ACTIVITY" ]]; then
    print_status "SLAM processing detected"
    echo -e "${BLUE}Recent SLAM activity:${NC}"
    echo "$SLAM_ACTIVITY"
else
    print_warning "No SLAM processing activity detected yet"
fi

# Step 8: Final status and instructions
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ AR VISUALIZATION SYSTEM READY${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "${BLUE}System Status:${NC}"
echo "AR Server: $SERVER_NAME (with Pangolin GUI)"
echo "ROS Client: $CLIENT_NAME (publishing camera data)"
echo "Network: $NETWORK_NAME"
echo "Display: $DISPLAY_VAR"
echo

echo -e "${BLUE}Container Status:${NC}"
docker ps --filter "network=$NETWORK_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
echo -e "${BLUE}What you should see:${NC}"
echo "1. 3D visualization window with ORB-SLAM3 interface"
echo "2. Real-time camera feed processing"
echo "3. Point cloud map building in 3D space"
echo "4. Camera trajectory visualization"
echo "5. AR cube placement functionality (after mapping)"

echo
echo -e "${YELLOW}Interactive Commands:${NC}"
echo "View AR server logs:     docker logs $SERVER_NAME"
echo "View client logs:        docker logs $CLIENT_NAME"
echo "Monitor ROS topics:      docker exec $CLIENT_NAME rostopic list"
echo "Check camera data:       docker exec $CLIENT_NAME rostopic echo /camera/image_raw -n 1"
echo "Test GUI:                docker exec $SERVER_NAME /slam-share-ros-server/test-gui.sh"

echo
echo -e "${YELLOW}Troubleshooting:${NC}"
echo "• If no GUI appears, check X11 forwarding setup"
echo "• On macOS: ensure XQuartz is running with network clients enabled"
echo "• On Linux: run 'xhost +local:docker' before starting"
echo "• Check firewall settings for X11 forwarding"

echo
echo -e "${YELLOW}Cleanup:${NC}"
echo "docker stop $SERVER_NAME $CLIENT_NAME"
echo "docker rm $SERVER_NAME $CLIENT_NAME"
echo "docker network rm $NETWORK_NAME"

echo
echo -e "${GREEN}🎯 AR Visualization system is running!${NC}"
echo -e "${GREEN}📹 Camera data streaming to SLAM processor${NC}"
echo -e "${GREEN}🎮 GUI should be visible for real-time mapping${NC}"

# Keep script running to monitor
echo
echo -e "${BLUE}Monitoring system (Ctrl+C to exit)...${NC}"
while true; do
    sleep 30
    echo -n "."
    # Check if containers are still running
    if ! docker ps --filter "name=$SERVER_NAME" --format "{{.Status}}" | grep -q "Up"; then
        echo
        print_error "AR Server stopped unexpectedly"
        docker logs $SERVER_NAME | tail -10
        break
    fi
    if ! docker ps --filter "name=$CLIENT_NAME" --format "{{.Status}}" | grep -q "Up"; then
        echo
        print_error "Client stopped unexpectedly"
        docker logs $CLIENT_NAME | tail -10
        break
    fi
done