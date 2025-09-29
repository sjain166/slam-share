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

# Install SLAM-Share dependencies
RUN apt-get update && apt-get install -y \
    libeigen3-dev \
    libboost-all-dev \
    libssl-dev \
    libpng-dev \
    libjpeg-dev \
    libtiff-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    && rm -rf /var/lib/apt/lists/*

# Build OpenCV 4.10.0 with NVIDIA support (NO cuDNN)
RUN cd /tmp && \
    wget -O opencv.zip https://github.com/opencv/opencv/archive/4.10.0.zip && \
    wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/4.10.0.zip && \
    unzip opencv.zip && unzip opencv_contrib.zip && \
    mkdir -p opencv-4.10.0/build && cd opencv-4.10.0/build && \
    cmake -D CMAKE_BUILD_TYPE=RELEASE \
          -D CMAKE_INSTALL_PREFIX=/usr/local \
          -D OPENCV_EXTRA_MODULES_PATH=/tmp/opencv_contrib-4.10.0/modules \
          -D WITH_CUDA=ON \
          -D WITH_CUBLAS=ON \
          -D WITH_CUFFT=ON \
          -D WITH_NVCUVID=ON \
          -D WITH_OPENGL=ON \
          -D WITH_GTK=ON \
          -D OPENCV_DNN_CUDA=OFF \
          -D OPENCV_ENABLE_NONFREE=ON \
          -D BUILD_opencv_python3=OFF \
          -D BUILD_EXAMPLES=OFF \
          -D BUILD_TESTS=OFF \
          -D BUILD_PERF_TESTS=OFF \
          .. && \
    make -j$(nproc) && make install && \
    rm -rf /tmp/opencv*

# Copy SLAM-Share source code from local directory
COPY . /slam-share

# Build SLAM-Share
WORKDIR /slam-share
RUN chmod +x build.sh && ./build.sh

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