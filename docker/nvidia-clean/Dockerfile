# SLAM-Share Clean NVIDIA Build
# Complete build from scratch with NVIDIA GPU support
FROM nvidia/cuda:11.8.0-devel-ubuntu20.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    pkg-config \
    software-properties-common \
    lsb-release \
    gnupg2 \
    ca-certificates \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install ROS Noetic
RUN echo "deb http://packages.ros.org/ros/ubuntu focal main" > /etc/apt/sources.list.d/ros-latest.list && \
    apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654 && \
    apt-get update && \
    apt-get install -y \
        ros-noetic-desktop-full \
        ros-noetic-roscpp \
        ros-noetic-tf \
        ros-noetic-cv-bridge \
        ros-noetic-image-transport \
        ros-noetic-sensor-msgs \
        python3-rosdep \
        python3-rosinstall \
        python3-rosinstall-generator \
        python3-wstool \
        python3-catkin-tools && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Initialize rosdep
RUN rosdep init && rosdep update

# Setup ROS environment
RUN echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc
ENV ROS_MASTER_URI=http://localhost:11311
ENV ROS_HOSTNAME=localhost
ENV ROS_DISTRO=noetic

# Install NVIDIA OpenGL and EGL libraries
RUN apt-get update && apt-get install -y \
    # NVIDIA OpenGL libraries
    libgl1-mesa-glx \
    libegl1-mesa \
    libgles2-mesa \
    # X11 and OpenGL development
    libx11-dev libxext-dev libxrender-dev \
    libxinerama-dev libxi-dev libxrandr-dev \
    libxcursor-dev libxdamage-dev libxcomposite-dev \
    libxtst-dev libxss-dev libxft-dev \
    # OpenGL utilities
    mesa-utils \
    # GTK for OpenCV
    libgtk-3-dev libgtk2.0-dev \
    # Additional OpenGL libraries
    libglew-dev \
    freeglut3-dev \
    libglfw3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install SLAM-Share dependencies including OpenCV from ROS Noetic
RUN apt-get update && apt-get install -y \
    libeigen3-dev \
    libboost-all-dev \
    libssl-dev \
    libopencv-dev \
    libopencv-contrib-dev \
    libpng-dev \
    libjpeg-dev \
    libtiff-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    && rm -rf /var/lib/apt/lists/*

# Verify OpenCV installation
RUN echo "=== OpenCV Version Check ===" && \
    pkg-config --modversion opencv4 || pkg-config --modversion opencv && \
    echo "=== Available OpenCV Libraries ===" && \
    ldconfig -p | grep opencv | head -5

# Build Pangolin from source (use stable v0.6 tag like successful build)
RUN echo "=== Building Pangolin from Source ===" && \
    cd /tmp && \
    # Clone Pangolin (use v0.6 tag - stable in 2021)
    git clone --branch v0.6 --depth 1 https://github.com/stevenlovegrove/Pangolin.git && \
    cd Pangolin && \
    mkdir build && cd build && \
    # Configure with CMake
    cmake .. -DCMAKE_BUILD_TYPE=Release \
             -DCMAKE_INSTALL_PREFIX=/usr/local \
             -DBUILD_EXAMPLES=OFF && \
    make -j$(nproc) && \
    make install && \
    # Update library cache
    ldconfig && \
    # Clean up source
    cd / && rm -rf /tmp/Pangolin && \
    echo "=========================="

# Set compilation flags (same as successful Dockerfile.base)
ENV CXXFLAGS="-O3 -march=native -Wno-deprecated-declarations -Wno-maybe-uninitialized -Wno-reorder"
ENV CMAKE_C_FLAGS="-Wall -O3 -march=native -Wno-deprecated-declarations -Wno-maybe-uninitialized"
ENV CMAKE_CXX_FLAGS="-Wall -O3 -march=native -Wno-deprecated-declarations -Wno-maybe-uninitialized -Wno-reorder"

# Copy SLAM-Share source code from local directory
COPY . /slam-share/

# Extract vocabulary (as per owner's build.sh)
RUN echo "=== Extracting ORB Vocabulary ===" && \
    cd /slam-share/Vocabulary && \
    tar -xf ORBvoc.txt.tar.gz && \
    echo "Vocabulary extracted successfully" && \
    echo "=========================="

# Build dependencies first (same as successful original build)
WORKDIR /slam-share

# Build DBoW2
RUN echo "=== Building DBoW2 ===" && \
    cd Thirdparty/DBoW2 && \
    mkdir -p build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release \
             -DCMAKE_C_FLAGS="$CMAKE_C_FLAGS" \
             -DCMAKE_CXX_FLAGS="$CMAKE_CXX_FLAGS" && \
    make -j$(nproc) && \
    echo "DBoW2 built successfully"

# Build g2o
RUN echo "=== Building g2o ===" && \
    cd Thirdparty/g2o && \
    mkdir -p build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release \
             -DCMAKE_C_FLAGS="$CMAKE_C_FLAGS" \
             -DCMAKE_CXX_FLAGS="$CMAKE_CXX_FLAGS" && \
    make -j$(nproc) && \
    echo "g2o built successfully"

# Build main SLAM-Share library
RUN echo "=== Building SLAM-Share Main Library ===" && \
    cd /slam-share && \
    mkdir -p build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release \
             -DCMAKE_C_FLAGS="$CMAKE_C_FLAGS" \
             -DCMAKE_CXX_FLAGS="$CMAKE_CXX_FLAGS" && \
    make -j$(nproc) && \
    echo "SLAM-Share library built successfully"

# Build ROS nodes with Noetic (including MonoAR - should work with OpenCV 4.x)
RUN /bin/bash -c "source /opt/ros/noetic/setup.bash && \
    export ROS_PACKAGE_PATH=/slam-share/Examples/ROS/ORB_SLAM3:\$ROS_PACKAGE_PATH && \
    cd Examples/ROS/ORB_SLAM3 && \
    mkdir -p build && cd build && \
    cmake .. -DROS_BUILD_TYPE=Release \
             -DCMAKE_C_FLAGS=\"\$CMAKE_C_FLAGS\" \
             -DCMAKE_CXX_FLAGS=\"\$CMAKE_CXX_FLAGS\" && \
    make -j\$(nproc)"

# Set NVIDIA environment variables
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=graphics,utility,compute
ENV QT_X11_NO_MITSHM=1

# Set library paths
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

# Copy server configuration files
RUN mkdir -p /slam-share-ros-server/config && \
    cp /slam-share/Examples/ROS/ORB_SLAM3/Asus.yaml /slam-share-ros-server/config/ && \
    cp /slam-share/Examples/Monocular/EuRoC.yaml /slam-share-ros-server/config/ && \
    echo "Available config files:" && \
    ls -la /slam-share-ros-server/config/

# Create NVIDIA-optimized startup script
RUN echo '#!/bin/bash' > /start-slam-nvidia.sh && \
    echo 'echo "=== SLAM-Share NVIDIA GPU Server ===\"' >> /start-slam-nvidia.sh && \
    echo 'source /opt/ros/noetic/setup.bash' >> /start-slam-nvidia.sh && \
    echo 'export ROS_MASTER_URI=http://slam-server:11311' >> /start-slam-nvidia.sh && \
    echo 'export ROS_HOSTNAME=slam-server' >> /start-slam-nvidia.sh && \
    echo 'export ROS_PACKAGE_PATH=/slam-share/Examples/ROS/ORB_SLAM3:$ROS_PACKAGE_PATH' >> /start-slam-nvidia.sh && \
    echo 'export DISPLAY=$DISPLAY' >> /start-slam-nvidia.sh && \
    echo 'echo "🚀 Starting ROS Master..."' >> /start-slam-nvidia.sh && \
    echo 'rosmaster --core -p 11311 &' >> /start-slam-nvidia.sh && \
    echo 'sleep 15' >> /start-slam-nvidia.sh && \
    echo 'echo "🎮 GPU Info:"' >> /start-slam-nvidia.sh && \
    echo 'nvidia-smi || echo "NVIDIA GPU not available"' >> /start-slam-nvidia.sh && \
    echo 'echo "🖥️  OpenGL Info:"' >> /start-slam-nvidia.sh && \
    echo 'glxinfo | head -10 || echo "OpenGL not available"' >> /start-slam-nvidia.sh && \
    echo 'echo "🎯 Starting SLAM with NVIDIA acceleration..."' >> /start-slam-nvidia.sh && \
    echo 'cd /slam-share/Examples/ROS/ORB_SLAM3' >> /start-slam-nvidia.sh && \
    echo 'rosrun ORB_SLAM3 Mono /slam-share/Vocabulary/ORBvoc.txt /slam-share-ros-server/config/Asus.yaml' >> /start-slam-nvidia.sh && \
    chmod +x /start-slam-nvidia.sh

WORKDIR /slam-share

CMD ["/start-slam-nvidia.sh"]