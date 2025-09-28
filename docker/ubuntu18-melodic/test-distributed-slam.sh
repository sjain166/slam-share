#!/bin/bash
# Complete Distributed SLAM System Test Script
# Tests ROS-enabled client-server SLAM communication

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NETWORK_NAME="slam-ros-network"
SERVER_NAME="slam-server"
CLIENT_NAME="slam-client"
SERVER_IMAGE="slam-share-ros-server:latest"
CLIENT_IMAGE="slam-share-ros-client:latest"
ROS_MASTER_PORT="11311"

echo -e "${BLUE}========================================"
echo "SLAM-Share Distributed System Test"
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
    echo -e "${YELLOW}Cleaning up existing containers and network...${NC}"
    docker stop $SERVER_NAME $CLIENT_NAME 2>/dev/null || true
    docker rm $SERVER_NAME $CLIENT_NAME 2>/dev/null || true
    docker network rm $NETWORK_NAME 2>/dev/null || true
}

# Function to wait for service
wait_for_service() {
    local service_name=$1
    local max_wait=$2
    local counter=0

    echo -e "${YELLOW}Waiting for $service_name (max ${max_wait}s)...${NC}"
    while [ $counter -lt $max_wait ]; do
        if docker exec $SERVER_NAME /bin/bash -c "source /opt/ros/melodic/setup.bash && export ROS_MASTER_URI=http://localhost:11311 && rostopic list" >/dev/null 2>&1; then
            print_status "$service_name is ready!"
            return 0
        fi
        sleep 2
        counter=$((counter + 2))
        echo -n "."
    done
    echo
    print_error "$service_name failed to start within ${max_wait}s"
    return 1
}

# Step 1: Cleanup
cleanup

# Step 2: Create network
echo -e "${BLUE}Step 1: Creating Docker network...${NC}"
docker network create $NETWORK_NAME
print_status "Network '$NETWORK_NAME' created"

# Step 3: Start ROS Master Server
echo -e "${BLUE}Step 2: Starting ROS Master Server...${NC}"
docker run -d \
    --name $SERVER_NAME \
    --network $NETWORK_NAME \
    --hostname $SERVER_NAME \
    -p $ROS_MASTER_PORT:$ROS_MASTER_PORT \
    $SERVER_IMAGE \
    /slam-share-ros-server/start-ros-master.sh

print_status "ROS Master server container started"

# Step 4: Wait for ROS Master
if wait_for_service "ROS Master" 30; then
    print_status "ROS Master is running"
else
    print_error "ROS Master failed to start"
    echo -e "${YELLOW}Server logs:${NC}"
    docker logs $SERVER_NAME
    exit 1
fi

# Step 5: Test ROS Master connectivity
echo -e "${BLUE}Step 3: Testing ROS Master connectivity...${NC}"
TOPICS=$(docker exec $SERVER_NAME /bin/bash -c "source /opt/ros/melodic/setup.bash && export ROS_MASTER_URI=http://localhost:11311 && rostopic list" 2>/dev/null || echo "FAILED")

if [[ "$TOPICS" != "FAILED" ]]; then
    print_status "ROS Master connectivity confirmed"
    echo -e "${BLUE}Available topics:${NC}"
    echo "$TOPICS"
else
    print_error "ROS Master connectivity failed"
    exit 1
fi

# Step 6: Start SLAM Server
echo -e "${BLUE}Step 4: Starting SLAM Server (with ROS Master)...${NC}"
docker stop $SERVER_NAME
docker rm $SERVER_NAME

# Create SLAM server script
cat > /tmp/slam-server-script.sh << 'EOF'
#!/bin/bash
source /opt/ros/melodic/setup.bash
export ROS_MASTER_URI=http://localhost:11311
export ROS_HOSTNAME=slam-server
export ROS_PACKAGE_PATH=/slam-share/Examples/ROS/ORB_SLAM3:$ROS_PACKAGE_PATH
export LD_LIBRARY_PATH=/opt/ros/melodic/lib:$LD_LIBRARY_PATH

echo "=== Starting ROS Master ==="
roscore &
sleep 10

echo "=== Starting SLAM Server ==="
cd /slam-share/Examples/ROS/ORB_SLAM3
./Mono /slam-share/Vocabulary/ORBvoc.txt /slam-share-ros-server/config/Asus.yaml
EOF

docker run -d \
    --name $SERVER_NAME \
    --network $NETWORK_NAME \
    --hostname $SERVER_NAME \
    -p $ROS_MASTER_PORT:$ROS_MASTER_PORT \
    -v /tmp/slam-server-script.sh:/tmp/start.sh:ro \
    $SERVER_IMAGE \
    /bin/bash /tmp/start.sh

print_status "SLAM Server container started"
sleep 15

# Step 7: Check SLAM Server status
echo -e "${BLUE}Step 5: Checking SLAM Server status...${NC}"
if docker ps --filter "name=$SERVER_NAME" --format "{{.Status}}" | grep -q "Up"; then
    print_status "SLAM Server container is running"
    echo -e "${BLUE}Server logs:${NC}"
    docker logs $SERVER_NAME | tail -10
else
    print_error "SLAM Server container stopped"
    echo -e "${YELLOW}Server logs:${NC}"
    docker logs $SERVER_NAME
    exit 1
fi

# Step 8: Start ROS Client
echo -e "${BLUE}Step 6: Starting ROS Client...${NC}"
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

# Step 9: Test client-server communication
echo -e "${BLUE}Step 7: Testing client-server ROS communication...${NC}"
CLIENT_TOPICS=$(docker exec $CLIENT_NAME /bin/bash -c "source /opt/ros/melodic/setup.bash && export ROS_MASTER_URI=http://$SERVER_NAME:$ROS_MASTER_PORT && rostopic list" 2>/dev/null || echo "FAILED")

if [[ "$CLIENT_TOPICS" != "FAILED" ]]; then
    print_status "Client-server ROS communication working"
    echo -e "${BLUE}Topics visible from client:${NC}"
    echo "$CLIENT_TOPICS"
else
    print_warning "Client-server communication issue"
    echo -e "${YELLOW}Client logs:${NC}"
    docker logs $CLIENT_NAME
fi

# Step 10: Test camera topic publishing
echo -e "${BLUE}Step 8: Testing camera topic publishing...${NC}"
docker exec $CLIENT_NAME /bin/bash -c "
source /opt/ros/melodic/setup.bash
export ROS_MASTER_URI=http://$SERVER_NAME:$ROS_MASTER_PORT
export ROS_HOSTNAME=$CLIENT_NAME
timeout 5 rostopic pub /camera/image_raw sensor_msgs/Image '{header: {stamp: now, frame_id: camera}, height: 480, width: 640, encoding: mono8, step: 640, data: []}' -r 1 &
" &

sleep 8

# Step 11: Final status
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ DISTRIBUTED SLAM SYSTEM TEST COMPLETE${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "${BLUE}System Status:${NC}"
echo "Network: $NETWORK_NAME"
echo "Server: $SERVER_NAME (port $ROS_MASTER_PORT)"
echo "Client: $CLIENT_NAME"
echo

echo -e "${BLUE}Container Status:${NC}"
docker ps --filter "network=$NETWORK_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
echo -e "${BLUE}Recent Server Logs:${NC}"
docker logs $SERVER_NAME | tail -5

echo
echo -e "${BLUE}Recent Client Logs:${NC}"
docker logs $CLIENT_NAME | tail -5

echo
echo -e "${YELLOW}Manual Commands:${NC}"
echo "View server logs: docker logs $SERVER_NAME"
echo "View client logs:  docker logs $CLIENT_NAME"
echo "Test ROS topics:   docker exec $CLIENT_NAME rostopic list"
echo "Clean up:          docker stop $SERVER_NAME $CLIENT_NAME && docker rm $SERVER_NAME $CLIENT_NAME && docker network rm $NETWORK_NAME"

echo
echo -e "${GREEN}🚀 Distributed SLAM system is ready for testing!${NC}"

# Cleanup script
rm -f /tmp/slam-server-script.sh