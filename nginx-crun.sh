#!/bin/bash

# Variables
IMAGE_URL_ARCH="https://quay.io/oci/archlinux:latest.tar"
IMAGE_FILE="arch-latest.tar"
DOWNLOAD_DIR="/tmp/arch_image"
BUNDLE_DIR="/tmp/arch_bundle"
IMAGE_ID="arch-latest-container"
BRIDGE_IP="10.10.10.114"
CONTAINER_IP="10.10.10.200/24"
HOST_CONFIG_DIR="/home/d/downlaods/crun/config"
HOST_MEDIA_DIR="/home/d/downlaods/media"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure necessary commands are available
for cmd in curl crun tar sudo chmod chown; do
    if ! command_exists "$cmd"; then
        echo "Error: $cmd is not installed. Please install it before running this script."
        exit 1
    fi
done

# Create download and bundle directories
mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$BUNDLE_DIR"
cd "$DOWNLOAD_DIR" || exit

# Download Arch image
echo "Downloading Arch latest image..."
curl -L -o "$IMAGE_FILE" "$IMAGE_URL_ARCH"

# Extract the image
echo "Extracting the image..."
tar -xvf "$IMAGE_FILE" -C "$BUNDLE_DIR"

# Turn off write protection, change ownership, and set correct permissions
echo "Removing write protection and adjusting permissions..."
sudo chmod -R u+w "$BUNDLE_DIR"
sudo chown -R $(id -u):$(id -g) "$BUNDLE_DIR"
sudo chmod -R 755 "$BUNDLE_DIR"

# Create config.json with network namespace configuration and mounts
echo "Creating config.json with network namespace and mounts..."
cat << EOF > "$BUNDLE_DIR/config.json"
{
    "ociVersion": "1.0.0",
    "process": {
        "args": ["/bin/sh"],
        "env": [
            "PATH=/usr/local/bin:/usr/bin:/bin"
        ],
        "cwd": "/",
        "terminal": false
    },
    "root": {
        "path": "rootfs",
        "readonly": false
    },
    "hostname": "arch-container",
    "linux": {
        "namespaces": [
            {"type": "pid"},
            {"type": "mount"},
            {"type": "network"}
        ]
    },
    "mounts": [
        {
            "destination": "/config",
            "source": "$HOST_CONFIG_DIR",
            "type": "bind",
            "options": ["rbind", "rw"]
        },
        {
            "destination": "/usr/share/nginx/html",
            "source": "$HOST_MEDIA_DIR",
            "type": "bind",
            "options": ["rbind", "ro"]
        }
    ]
}
EOF

# Setup network namespace manually before running the container
echo "Setting up network namespace..."
sudo ip netns add "$IMAGE_ID"
sudo ip link add veth0 type veth peer name veth1
sudo ip link set veth0 netns "$IMAGE_ID"
sudo ip link set veth1 master br0
sudo ip link set veth1 up

# Enter container namespace to configure network
sudo ip netns exec "$IMAGE_ID" ip link set veth0 name eth0
sudo ip netns exec "$IMAGE_ID" ip link set eth0 up
sudo ip netns exec "$IMAGE_ID" ip addr add "$CONTAINER_IP" dev eth0
sudo ip netns exec "$IMAGE_ID" ip route add default via "$BRIDGE_IP"

# Run the container in the background
echo "Running the container with crun in background..."
sudo crun run -d --bundle "$BUNDLE_DIR" "$IMAGE_ID"

# Install additional packages inside the container
echo "Installing additional packages inside the container..."
sudo crun exec "$IMAGE_ID" pacman -Syu --noconfirm
sudo crun exec "$IMAGE_ID" pacman -S --noconfirm nginx transmission-cli

# Configure Nginx to serve static content from /media
echo "Configuring Nginx to serve static content..."
# Assuming a basic Nginx configuration file at /config/nginx.conf in the host
sudo crun exec "$IMAGE_ID" sh -c 'echo "server {
    listen 80;
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
    }
}" > /config/nginx.conf'

# Move or symlink Nginx configuration to the correct location
sudo crun exec "$IMAGE_ID" ln -s /config/nginx.conf /etc/nginx/nginx.conf

# Start Nginx
sudo crun exec "$IMAGE_ID" systemctl start nginx

echo "Container $IMAGE_ID is running in the background with network namespace, Nginx configured to serve static content from /media, and config mounted from $HOST_CONFIG_DIR."

# # Commented out cleanup
# echo "Cleaning up..."
# rm -f "$DOWNLOAD_DIR/$IMAGE_FILE"