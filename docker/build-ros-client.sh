#!/bin/bash
# Build script for SLAM-Share ROS Client

set -e

echo "========================================"
echo "Building SLAM-Share ROS Client"
echo "========================================"

# Check if base image exists
if ! docker images slam-share:latest --format "table" | grep -q slam-share; then
    echo "Error: slam-share:latest base image not found!"
    echo "Please build the base image first."
    exit 1
fi

echo "Building ROS client container..."
docker build -f docker/Dockerfile.ros-client -t slam-share-ros-client:latest .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ ROS Client build completed successfully!"
    echo ""
    echo "Image: slam-share-ros-client:latest"
    echo "Features:"
    echo "  - ROS Melodic integration"
    echo "  - Camera data streaming via ROS topics"
    echo "  - Built-in SLAM processing with networking"
    echo "  - Compatible with ROS-enabled server"
    echo ""
    echo "To test:"
    echo "docker run --rm --name slam-ros-client slam-share-ros-client:latest"
else
    echo "❌ Build failed!"
    exit 1
fi