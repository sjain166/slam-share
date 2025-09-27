#!/bin/bash

# SLAM-Share Base Image Build Script
# Step 1: Ubuntu 18.04 + Essential Build Tools

set -e  # Exit on any error

# Configuration
IMAGE_NAME="slam-share-base"
IMAGE_TAG="step1-ubuntu18.04"
DOCKERFILE="Dockerfile.base"

echo "================================================="
echo "SLAM-Share Docker Build - Step 1"
echo "Building base image with Ubuntu 18.04 + build tools"
echo "================================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker is not running. Please start Docker first."
    exit 1
fi

# Check if Dockerfile exists
if [ ! -f "$DOCKERFILE" ]; then
    echo "ERROR: $DOCKERFILE not found in current directory"
    exit 1
fi

# Build the image
echo "Building Docker image: $IMAGE_NAME:$IMAGE_TAG"
echo "Using Dockerfile: $DOCKERFILE"

docker build \
    -f "$DOCKERFILE" \
    -t "$IMAGE_NAME:$IMAGE_TAG" \
    --progress=plain \
    .

# Verify the build
if [ $? -eq 0 ]; then
    echo ""
    echo "================================================="
    echo "✅ SUCCESS: Base image built successfully!"
    echo "================================================="
    echo "Image: $IMAGE_NAME:$IMAGE_TAG"
    echo ""
    echo "To test the image, run:"
    echo "docker run -it --rm $IMAGE_NAME:$IMAGE_TAG"
    echo ""
    echo "To validate build environment:"
    echo "docker run --rm $IMAGE_NAME:$IMAGE_TAG bash -c 'echo \"\$(cmake --version | head -1)\" && echo \"\$(g++ --version | head -1)\"'"
    echo ""
else
    echo ""
    echo "================================================="
    echo "❌ ERROR: Build failed!"
    echo "================================================="
    exit 1
fi