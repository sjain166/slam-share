#!/bin/bash
# Fix for MonoAR shared memory pointer type conversion
# This script fixes the boost::interprocess::offset_ptr issues in ROS AR code

echo "=== Applying MonoAR shared memory pointer fix ==="

AR_FILE="/slam-share/Examples/ROS/ORB_SLAM3/src/AR/ros_mono_ar.cc"

if [ -f "$AR_FILE" ]; then
    echo "Fixing $AR_FILE"

    # Check if the fix is already applied
    if grep -q "vMPsOffset" "$AR_FILE"; then
        echo "✅ Fix already applied to $AR_FILE"
    else
        echo "Applying fix to $AR_FILE"

        # Add boost header after opencv includes
        sed -i '/^#include<opencv2\/imgproc\/imgproc.hpp>$/a\\n#include<boost/interprocess/offset_ptr.hpp>' "$AR_FILE"

        # Fix the GetTrackedMapPoints call
        sed -i 's/vector<ORB_SLAM3::MapPoint\*> vMPs = mpSLAM->GetTrackedMapPoints();/std::vector<boost::interprocess::offset_ptr<ORB_SLAM3::MapPoint> > vMPsOffset = mpSLAM->GetTrackedMapPoints();\
    vector<ORB_SLAM3::MapPoint*> vMPs;\
    vMPs.reserve(vMPsOffset.size());\
    for(const auto\& mp : vMPsOffset) {\
        vMPs.push_back(mp.get());\
    }/' "$AR_FILE"

        echo "✅ Fix applied to $AR_FILE"
    fi
else
    echo "❌ File not found: $AR_FILE"
    exit 1
fi

echo "=== MonoAR fix completed ==="