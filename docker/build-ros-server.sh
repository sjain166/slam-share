#!/bin/bash
# Build script for SLAM-Share ROS Server with GUI

set -e

echo "========================================"
echo "Building SLAM-Share ROS Server with GUI"
echo "========================================"

# Check if base image exists
if ! docker images slam-share:latest --format "table" | grep -q slam-share; then
    echo "Error: slam-share:latest base image not found!"
    echo "Please build the base image first."
    exit 1
fi

echo "Building ROS server container with AR visualization..."
docker build -f docker/Dockerfile.ros-server -t slam-share-ros-server:latest .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ ROS Server build completed successfully!"
    echo ""
    echo "Image: slam-share-ros-server:latest"
    echo "Features:"
    echo "  - ROS Melodic master"
    echo "  - Real-time 3D visualization with ViewerAR"
    echo "  - Augmented Reality cube placement"
    echo "  - X11 GUI support"
    echo "  - Camera data processing via ROS topics"
    echo ""
    echo "Available startup scripts:"
    echo "  - /slam-share-ros-server/start-ar-server.sh (AR + GUI)"
    echo "  - /slam-share-ros-server/start-slam-server.sh (Basic SLAM)"
    echo "  - /slam-share-ros-server/start-ros-master.sh (ROS master only)"
    echo "  - /slam-share-ros-server/test-gui.sh (GUI test)"
    echo ""
    echo "To test with GUI:"
    echo "docker run --rm -e DISPLAY=\$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix --name slam-ros-server slam-share-ros-server:latest"
else
    echo "❌ Build failed!"
    exit 1
fi