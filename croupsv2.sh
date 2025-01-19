#!/bin/bash

# Function to check cgroup version
check_cgroup_version() {
    echo "Checking cgroup version..."
    if [[ -f /proc/cgroups ]]; then
        if grep -q '1' /proc/cgroups; then
            echo "System is using cgroup v1."
        else
            echo "System appears to be using cgroup v2."
        fi
    else
        echo "Unable to determine cgroup version from /proc/cgroups. Assuming cgroup v2."
    fi
    echo "Current cgroup structure:"
    ls -l /sys/fs/cgroup
}

# Function to prepare cgroup v2 environment
prepare_cgroup_v2() {
    echo "Preparing cgroup v2 environment..."
    if ! mount | grep -q "/sys/fs/cgroup cgroup2"; then
        echo "Mounting unified cgroup2 filesystem..."
        if mount -t cgroup2 none /sys/fs/cgroup; then
            echo "Successfully mounted cgroup2."
        else
            echo "Failed to mount cgroup2. Check if cgroup2 support is enabled in your kernel."
        fi
    else
        echo "cgroup2 is already mounted."
    fi
    echo "Cgroup v2 preparation completed."
}

# Function to verify cgroup setup
verify_cgroup() {
    echo "Verifying cgroup setup..."
    ls -l /sys/fs/cgroup
    echo "Verification completed."
}

# Main function
main() {
    check_cgroup_version
    prepare_cgroup_v2
    verify_cgroup
}

# Run the main function
main