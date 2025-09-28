# Manual Steps for Distributed SLAM Testing

If the scripts fail, follow these manual steps to test the distributed SLAM system step by step.

## Step 1: Clean up
```powershell
# Stop and remove any existing containers
docker stop slam-server slam-client
docker rm slam-server slam-client
docker network rm slam-ros-network
```

## Step 2: Create network
```powershell
docker network create slam-ros-network
```

## Step 3: Test ROS Master only
```powershell
# Start ROS Master
docker run -d --name slam-server --network slam-ros-network --hostname slam-server -p 11311:11311 slam-share-ros-server:latest /slam-share-ros-server/start-ros-master.sh

# Wait and check
Start-Sleep 10
docker logs slam-server

# Test ROS Master
docker exec slam-server /bin/bash -c "source /opt/ros/melodic/setup.bash && export ROS_MASTER_URI=http://localhost:11311 && rostopic list"
```

**If ROS Master works, continue to Step 4. If not, debug the ROS Master startup.**

## Step 4: Test SLAM Server
```powershell
# Stop ROS Master only container
docker stop slam-server
docker rm slam-server

# Start SLAM Server with manual command
docker run -d --name slam-server --network slam-ros-network --hostname slam-server -p 11311:11311 slam-share-ros-server:latest /bin/bash -c "
source /opt/ros/melodic/setup.bash
export ROS_MASTER_URI=http://localhost:11311
export ROS_HOSTNAME=slam-server
export ROS_PACKAGE_PATH=/slam-share/Examples/ROS/ORB_SLAM3:\$ROS_PACKAGE_PATH
export LD_LIBRARY_PATH=/opt/ros/melodic/lib:\$LD_LIBRARY_PATH
echo 'Starting ROS Master...'
roscore &
sleep 10
echo 'Starting SLAM Server...'
cd /slam-share/Examples/ROS/ORB_SLAM3
./Mono /slam-share/Vocabulary/ORBvoc.txt /slam-share-ros-server/config/Asus.yaml
"

# Wait and check
Start-Sleep 15
docker logs slam-server
docker ps | Select-String slam-server
```

**If SLAM server starts and waits for camera data, continue to Step 5.**

## Step 5: Test ROS Client
```powershell
# Start client
docker run -d --name slam-client --network slam-ros-network --hostname slam-client -e ROS_MASTER_URI=http://slam-server:11311 -e ROS_HOSTNAME=slam-client slam-share-ros-client:latest /slam-share-ros-client/start-ros-client.sh

# Wait and check
Start-Sleep 10
docker logs slam-client

# Test client ROS connectivity
docker exec slam-client /bin/bash -c "source /opt/ros/melodic/setup.bash && export ROS_MASTER_URI=http://slam-server:11311 && rostopic list"
```

## Step 6: Test camera data publishing
```powershell
# Publish test camera data
docker exec slam-client /bin/bash -c "
source /opt/ros/melodic/setup.bash
export ROS_MASTER_URI=http://slam-server:11311
export ROS_HOSTNAME=slam-client
rostopic pub /camera/image_raw sensor_msgs/Image '{header: {stamp: now, frame_id: camera}, height: 480, width: 640, encoding: mono8, step: 640, data: []}' -r 1
"
```

## Debugging Commands

### Check container status
```powershell
docker ps -a
docker logs slam-server
docker logs slam-client
```

### Check ROS topics
```powershell
docker exec slam-server rostopic list
docker exec slam-client rostopic list
```

### Check ROS connectivity
```powershell
docker exec slam-client /bin/bash -c "source /opt/ros/melodic/setup.bash && export ROS_MASTER_URI=http://slam-server:11311 && rostopic info /rosout"
```

### Interactive debugging
```powershell
# Enter server container
docker exec -it slam-server /bin/bash

# Enter client container
docker exec -it slam-client /bin/bash
```

## Expected Results

1. **ROS Master**: Should show `/rosout` and `/rosout_agg` topics
2. **SLAM Server**: Should show ORB-SLAM3 copyright and "Input sensor was set to: Monocular", then wait for camera data
3. **Client**: Should connect to server and show ROS topics
4. **Camera publishing**: Should show data being sent to `/camera/image_raw` topic

## Cleanup
```powershell
docker stop slam-server slam-client
docker rm slam-server slam-client
docker network rm slam-ros-network
```