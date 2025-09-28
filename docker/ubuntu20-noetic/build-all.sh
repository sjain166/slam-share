#!/bin/bash
# Complete ROS Noetic SLAM-Share Build Script
# Builds all images incrementally for Ubuntu 20.04 + ROS Noetic

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================="
echo "SLAM-Share ROS Noetic Build Script"
echo "Ubuntu 20.04 + ROS Noetic + OpenCV 4.x"
echo -e "=========================================${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Build Phase 1: Base image
echo -e "${BLUE}Phase 1: Building base image (Ubuntu 20.04 + ROS Noetic)...${NC}"
docker build -f ubuntu20-noetic/Dockerfile.base -t slam-share-noetic-base:latest .
if [ $? -eq 0 ]; then
    print_status "Base image built successfully"
else
    print_error "Base image build failed"
    exit 1
fi

# Build Phase 2: SLAM system
echo -e "${BLUE}Phase 2: Building SLAM system...${NC}"
docker build -f ubuntu20-noetic/Dockerfile.slam -t slam-share-noetic:latest .
if [ $? -eq 0 ]; then
    print_status "SLAM system built successfully"
else
    print_error "SLAM system build failed"
    exit 1
fi

# Build Phase 3: Server image
echo -e "${BLUE}Phase 3: Building server image...${NC}"
docker build -f ubuntu20-noetic/Dockerfile.server -t slam-share-noetic-server:latest .
if [ $? -eq 0 ]; then
    print_status "Server image built successfully"
else
    print_error "Server image build failed"
    exit 1
fi

# Build Phase 4: Client image
echo -e "${BLUE}Phase 4: Building client image...${NC}"
docker build -f ubuntu20-noetic/Dockerfile.client -t slam-share-noetic-client:latest .
if [ $? -eq 0 ]; then
    print_status "Client image built successfully"
else
    print_error "Client image build failed"
    exit 1
fi

echo -e "${BLUE}========================================="
echo -e "${GREEN}✅ ALL BUILDS COMPLETED SUCCESSFULLY"
echo -e "${BLUE}=========================================${NC}"

echo -e "${BLUE}Built Images:${NC}"
echo "1. slam-share-noetic-base:latest    - Ubuntu 20.04 + ROS Noetic base"
echo "2. slam-share-noetic:latest         - Core SLAM system"
echo "3. slam-share-noetic-server:latest  - SLAM server"
echo "4. slam-share-noetic-client:latest  - SLAM client"

echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Test core system: docker run -it slam-share-noetic:latest /slam-share-test/test-core-slam.sh"
echo "2. Test server: docker run -it slam-share-noetic-server:latest /slam-share-ros-server/test-server.sh"
echo "3. Test distributed system with provided test scripts"

echo ""
echo -e "${GREEN}🚀 ROS Noetic SLAM-Share system ready for testing!${NC}"