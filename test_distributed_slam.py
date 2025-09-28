#!/usr/bin/env python3
"""
Distributed SLAM Testing Script
Automates the complete testing workflow for SLAM-Share with EuRoC dataset
"""

import subprocess
import time
import sys
import os
from pathlib import Path

class DistributedSLAMTester:
    def __init__(self, bag_file_path="C:/Users/sj99/Desktop/slam-share/MH_01_easy.bag"):
        self.bag_file_path = bag_file_path
        self.network_name = "slam-network"
        self.server_name = "slam-server"
        self.client_name = "slam-client"

    def run_command(self, command, description="", check_output=False, timeout=30):
        """Execute a command and handle output"""
        print(f"\n🔄 {description}")
        print(f"Command: {command}")

        try:
            if check_output:
                result = subprocess.run(command, shell=True, capture_output=True,
                                     text=True, timeout=timeout)
                if result.returncode == 0:
                    print(f"✅ Success: {description}")
                    return result.stdout.strip()
                else:
                    print(f"❌ Failed: {description}")
                    print(f"Error: {result.stderr}")
                    return None
            else:
                result = subprocess.run(command, shell=True, timeout=timeout)
                if result.returncode == 0:
                    print(f"✅ Success: {description}")
                    return True
                else:
                    print(f"❌ Failed: {description}")
                    return False
        except subprocess.TimeoutExpired:
            print(f"⏰ Timeout: {description}")
            return False
        except Exception as e:
            print(f"❌ Error: {description} - {e}")
            return False

    def phase1_cleanup(self):
        """Phase 1: Clean Docker environment"""
        print("\n" + "="*60)
        print("PHASE 1: CLEANING DOCKER ENVIRONMENT")
        print("="*60)

        # Stop containers
        self.run_command(f"docker stop {self.server_name} {self.client_name}",
                        "Stopping existing containers")

        # Remove containers
        self.run_command(f"docker rm {self.server_name} {self.client_name}",
                        "Removing existing containers")

        # Check clean state
        output = self.run_command("docker ps", "Checking running containers", check_output=True)
        if output is not None:
            print(f"Running containers:\n{output}")

    def phase2_setup_network(self):
        """Phase 2: Verify and create network"""
        print("\n" + "="*60)
        print("PHASE 2: NETWORK SETUP")
        print("="*60)

        # Check if network exists
        output = self.run_command("docker network ls", "Checking existing networks", check_output=True)
        if output and self.network_name in output:
            print(f"✅ Network {self.network_name} already exists")
        else:
            # Create network
            self.run_command(f"docker network create {self.network_name}",
                           f"Creating {self.network_name} network")

    def phase3_start_server(self):
        """Phase 3: Start SLAM server"""
        print("\n" + "="*60)
        print("PHASE 3: STARTING SLAM SERVER")
        print("="*60)

        server_command = f'''docker run -d --name {self.server_name} --network {self.network_name} -p 11311:11311 slam-share-ros-server:latest bash -c "
source /opt/ros/noetic/setup.bash
export ROS_MASTER_URI=http://localhost:11311
export ROS_HOSTNAME={self.server_name}
export ROS_PACKAGE_PATH=/slam-share/Examples/ROS/ORB_SLAM3:\\$ROS_PACKAGE_PATH
export DISPLAY=
nohup rosmaster --core -p 11311 &
sleep 15
echo 'Starting SLAM node (headless)...'
rosrun ORB_SLAM3 Mono /slam-share/Vocabulary/ORBvoc.txt /slam-share-ros-server/config/Asus.yaml &
tail -f /dev/null
"'''

        success = self.run_command(server_command, "Starting SLAM server container")
        if success:
            print("⏳ Waiting for server initialization (60 seconds)...")
            time.sleep(60)
        return success

    def phase4_verify_server(self):
        """Phase 4: Verify server readiness"""
        print("\n" + "="*60)
        print("PHASE 4: VERIFYING SERVER READINESS")
        print("="*60)

        # Check server logs
        logs = self.run_command(f"docker logs {self.server_name}",
                               "Checking server logs", check_output=True)

        if logs:
            print("Server logs:")
            print(logs[-1000:])  # Show last 1000 characters

            # Check for key initialization markers
            if "Vocabulary loaded!" in logs:
                print("✅ Vocabulary loaded successfully")
            if "ORB Extractor Parameters:" in logs:
                print("✅ SLAM system initialized")
            if "Camera Parameters:" in logs:
                print("✅ Camera parameters loaded")

        # Check if container is running
        output = self.run_command(f"docker ps --filter name={self.server_name}",
                                 "Checking server container status", check_output=True)

        return self.server_name in output if output else False

    def phase5_start_client(self):
        """Phase 5: Start client container"""
        print("\n" + "="*60)
        print("PHASE 5: STARTING CLIENT CONTAINER")
        print("="*60)

        # Check if bag file exists
        if not os.path.exists(self.bag_file_path.replace('C:/', '/mnt/c/').replace('\\', '/')):
            # Try Windows path
            if not os.path.exists(self.bag_file_path):
                print(f"❌ ROS bag file not found: {self.bag_file_path}")
                return False

        print(f"📁 Using ROS bag: {self.bag_file_path}")

        # Start client container interactively
        client_command = f'''docker run -it --rm --network {self.network_name} -v "{self.bag_file_path.replace(chr(92), '/')}:/data/MH_01_easy.bag" -e ROS_MASTER_URI=http://{self.server_name}:11311 slam-share-ros-client:latest bash'''

        print(f"\n🚀 Starting client container...")
        print(f"Command: {client_command}")
        print("\n" + "="*60)
        print("MANUAL STEPS FOR CLIENT CONTAINER:")
        print("="*60)
        print("1. Copy and run the above command in a new terminal")
        print("2. Inside the container, run these commands:")
        print("   source /opt/ros/noetic/setup.bash")
        print("   export ROS_HOSTNAME=slam-client")
        print("   ping slam-server  # Test connectivity")
        print("   rostopic list    # Test ROS connection")
        print("3. If connectivity works, proceed to Phase 6")
        print("="*60)

        return True

    def phase6_test_connectivity(self):
        """Phase 6: Test client-server connectivity"""
        print("\n" + "="*60)
        print("PHASE 6: TESTING CONNECTIVITY")
        print("="*60)

        print("Manual verification steps:")
        print("1. From inside client container, test network:")
        print("   ping slam-server")
        print("2. Test ROS Master connection:")
        print("   rostopic list")
        print("3. You should see /rosout topic if connection works")

        input("\nPress Enter when connectivity test is complete...")

    def phase7_play_rosbag(self):
        """Phase 7: Play ROS bag"""
        print("\n" + "="*60)
        print("PHASE 7: PLAYING ROS BAG")
        print("="*60)

        print("In the client container, run:")
        print("rosbag play /data/MH_01_easy.bag /cam0/image_raw:=/camera/image_raw --clock")
        print("\nThis will:")
        print("- Read camera frames from EuRoC dataset")
        print("- Remap /cam0/image_raw to /camera/image_raw")
        print("- Publish with simulation time")

        input("\nPress Enter when ROS bag is playing...")

    def phase8_monitor_slam(self):
        """Phase 8: Monitor SLAM processing"""
        print("\n" + "="*60)
        print("PHASE 8: MONITORING SLAM PROCESSING")
        print("="*60)

        print("To monitor SLAM processing, run in another terminal:")
        print(f"docker logs -f {self.server_name}")
        print("\nLook for:")
        print("- Image processing messages")
        print("- Tracking status updates")
        print("- Keyframe creation")
        print("- Map building progress")

        # Show recent logs
        logs = self.run_command(f"docker logs --tail 20 {self.server_name}",
                               "Showing recent server logs", check_output=True)
        if logs:
            print("\nRecent server logs:")
            print(logs)

    def run_complete_test(self):
        """Run the complete testing workflow"""
        print("🚀 DISTRIBUTED SLAM TESTING AUTOMATION")
        print("🎯 Testing SLAM-Share with EuRoC MH_01_easy.bag")
        print("="*60)

        try:
            # Phase 1: Cleanup
            self.phase1_cleanup()

            # Phase 2: Network setup
            self.phase2_setup_network()

            # Phase 3: Start server
            if not self.phase3_start_server():
                print("❌ Failed to start server. Exiting.")
                return False

            # Phase 4: Verify server
            if not self.phase4_verify_server():
                print("❌ Server verification failed. Check logs.")
                return False

            # Phase 5: Start client (manual)
            if not self.phase5_start_client():
                print("❌ Client setup failed.")
                return False

            # Phase 6: Test connectivity (manual)
            self.phase6_test_connectivity()

            # Phase 7: Play ROS bag (manual)
            self.phase7_play_rosbag()

            # Phase 8: Monitor SLAM (manual)
            self.phase8_monitor_slam()

            print("\n🎉 DISTRIBUTED SLAM TESTING WORKFLOW COMPLETE!")
            print("Your system should now be processing real EuRoC camera data!")

            return True

        except KeyboardInterrupt:
            print("\n⏹️  Testing interrupted by user")
            return False
        except Exception as e:
            print(f"\n❌ Unexpected error: {e}")
            return False

def main():
    # Check if custom bag file path provided
    bag_path = "C:/Users/sj99/Desktop/slam-share/MH_01_easy.bag"
    if len(sys.argv) > 1:
        bag_path = sys.argv[1]

    print(f"Using ROS bag: {bag_path}")

    tester = DistributedSLAMTester(bag_path)
    success = tester.run_complete_test()

    if success:
        print("\n✅ Testing completed successfully!")
    else:
        print("\n❌ Testing failed. Check the logs above.")

    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())