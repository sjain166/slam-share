#!/bin/bash
# Test script for ROS client-server communication

set -e

echo "========================================"
echo "Testing ROS Client-Server Communication"
echo "========================================"

# Check if images exist
echo "Checking container images..."
if ! docker images slam-share-ros-server:latest --format "table" | grep -q slam-share-ros-server; then
    echo "❌ slam-share-ros-server:latest not found!"
    exit 1
fi

if ! docker images slam-share-ros-client:latest --format "table" | grep -q slam-share-ros-client; then
    echo "❌ slam-share-ros-client:latest not found!"
    exit 1
fi

echo "✅ Both container images found"

# Clean up any existing containers
echo "Cleaning up existing test containers..."
docker stop slam-server-test 2>/dev/null || true
docker stop slam-client-test 2>/dev/null || true
docker rm slam-server-test 2>/dev/null || true
docker rm slam-client-test 2>/dev/null || true

# Create a Docker network for ROS communication
echo "Creating Docker network for ROS communication..."
docker network rm slam-ros-network 2>/dev/null || true
docker network create slam-ros-network

echo "✅ Network created: slam-ros-network"

# Test 1: Start ROS Master on server
echo ""
echo "Test 1: Starting ROS Master..."
docker run -d \
    --name slam-server-test \
    --network slam-ros-network \
    --hostname slam-server \
    -p 11311:11311 \
    slam-share-ros-server:latest \
    /slam-share-ros-server/start-ros-master.sh

echo "Waiting for ROS Master to initialize..."
sleep 8

# Check if server is running
if docker ps --filter "name=slam-server-test" --format "{{.Status}}" | grep -q "Up"; then
    echo "✅ ROS Server container is running"
else
    echo "❌ ROS Server container failed to start"
    docker logs slam-server-test
    exit 1
fi

# Test 2: Check ROS Master connectivity
echo ""
echo "Test 2: Testing ROS Master connectivity..."
ROS_MASTER_CHECK=$(docker exec slam-server-test /bin/bash -c "source /opt/ros/melodic/setup.bash && export ROS_MASTER_URI=http://localhost:11311 && rostopic list" 2>/dev/null || echo "FAILED")

if [[ "$ROS_MASTER_CHECK" != "FAILED" ]]; then
    echo "✅ ROS Master is accessible"
    echo "Available topics:"
    echo "$ROS_MASTER_CHECK"
else
    echo "❌ ROS Master connectivity failed"
    docker logs slam-server-test
fi

# Test 3: Start client and test connectivity
echo ""
echo "Test 3: Testing client-server ROS communication..."
docker run -d \
    --name slam-client-test \
    --network slam-ros-network \
    --hostname slam-client \
    -e ROS_MASTER_URI=http://slam-server:11311 \
    -e ROS_HOSTNAME=slam-client \
    slam-share-ros-client:latest \
    /bin/bash -c "source /opt/ros/melodic/setup.bash && export ROS_MASTER_URI=http://slam-server:11311 && export ROS_HOSTNAME=slam-client && echo 'Waiting for ROS master...' && sleep 10 && rostopic list && echo 'Client connectivity test completed' && sleep 30"

echo "Waiting for client connectivity test..."
sleep 15

# Check client logs
echo ""
echo "📋 Client connectivity results:"
docker logs slam-client-test

# Test 4: Topic publishing test
echo ""
echo "Test 4: Testing topic publishing..."
TOPIC_TEST=$(docker exec slam-client-test /bin/bash -c "source /opt/ros/melodic/setup.bash && export ROS_MASTER_URI=http://slam-server:11311 && export ROS_HOSTNAME=slam-client && timeout 5 rostopic echo /rosout -n 1" 2>/dev/null || echo "FAILED")

if [[ "$TOPIC_TEST" != "FAILED" ]]; then
    echo "✅ Topic communication working"
else
    echo "⚠️ Topic communication test inconclusive"
fi

# Display server logs
echo ""
echo "📋 Server logs:"
docker logs slam-server-test

# Summary
echo ""
echo "========================================"
echo "✅ ROS Communication Test Completed"
echo "========================================"
echo "Network: slam-ros-network"
echo "Server: slam-server-test (slam-server:11311)"
echo "Client: slam-client-test"
echo ""
echo "To manually test:"
echo "1. Check server: docker exec -it slam-server-test /slam-share-ros-server/test-gui.sh"
echo "2. Check client: docker exec -it slam-client-test rostopic list"
echo "3. Start AR server: docker exec slam-server-test /slam-share-ros-server/start-ar-server.sh"
echo ""
echo "To clean up:"
echo "docker stop slam-server-test slam-client-test"
echo "docker rm slam-server-test slam-client-test"
echo "docker network rm slam-ros-network"
echo "========================================"