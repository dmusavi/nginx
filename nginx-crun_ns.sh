#!/bin/bash

# Variables
IMAGE_URL_ARCH="https://quay.io/oci/archlinux:latest.tar"
IMAGE_FILE="arch-latest.tar"
DOWNLOAD_DIR="/tmp/arch_image"
BUNDLE_DIR="/tmp/arch_bundle"
IMAGE_ID="arch-latest-container"
NETNS_NAME="arch-netns"
HOST_BRIDGE_IP="10.10.10.1/24"
CONTAINER_IP="10.10.10.200/24"
HOST_CONFIG_DIR="/home/d/config"
HOST_NGINX_CONF="$HOST_CONFIG_DIR/nginx.conf"
HOST_MEDIA_DIR="/home/d/downloads/media"

# Ensure necessary commands are available
for cmd in curl crun tar sudo chmod chown ip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is not installed. Please install it before running this script."
        exit 1
    fi
done

# Create necessary directories
mkdir -p "$DOWNLOAD_DIR" "$BUNDLE_DIR/rootfs" "$HOST_CONFIG_DIR"

# Download Arch image
if [ ! -f "$DOWNLOAD_DIR/$IMAGE_FILE" ]; then
    echo "Downloading Arch latest image..."
    curl -L -o "$DOWNLOAD_DIR/$IMAGE_FILE" "$IMAGE_URL_ARCH"
fi

# Extract the image
echo "Extracting the image..."
tar -xvf "$DOWNLOAD_DIR/$IMAGE_FILE" -C "$BUNDLE_DIR/rootfs"

# Create default Nginx config if it doesn't exist
if [ ! -f "$HOST_NGINX_CONF" ]; then
    echo "Creating default Nginx config..."
    cat <<EOF > "$HOST_NGINX_CONF"
server {
    listen 80;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html;
        autoindex on;
    }
}
EOF
fi

# Create config.json for crun
echo "Creating config.json..."
cat <<EOF > "$BUNDLE_DIR/config.json"
{
    "ociVersion": "1.0.0",
    "process": {
        "args": ["/usr/bin/nginx", "-g", "daemon off;"],
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
            "destination": "/etc/nginx/nginx.conf",
            "source": "$HOST_NGINX_CONF",
            "type": "bind",
            "options": ["ro"]
        },
        {
            "destination": "/usr/share/nginx/html",
            "source": "$HOST_MEDIA_DIR",
            "type": "bind",
            "options": ["ro"]
        }
    ]
}
EOF

# Create and configure the network namespace
echo "Setting up network namespace..."
sudo ip netns add "$NETNS_NAME"
sudo ip link add veth0 type veth peer name veth1
sudo ip link set veth0 netns "$NETNS_NAME"
sudo ip addr add "$HOST_BRIDGE_IP" dev veth1
sudo ip link set veth1 up
sudo ip netns exec "$NETNS_NAME" ip addr add "$CONTAINER_IP" dev veth0
sudo ip netns exec "$NETNS_NAME" ip link set veth0 up
sudo ip netns exec "$NETNS_NAME" ip route add default via "${HOST_BRIDGE_IP%/*}"

# Start the container inside the namespace
echo "Starting the container..."
sudo ip netns exec "$NETNS_NAME" crun run "$IMAGE_ID"

# Initialize pacman and install Nginx
echo "Installing Nginx inside the container..."
sudo ip netns exec "$NETNS_NAME" crun exec "$IMAGE_ID" pacman-key --init
sudo ip netns exec "$NETNS_NAME" crun exec "$IMAGE_ID" pacman-key --populate archlinux
sudo ip netns exec "$NETNS_NAME" crun exec "$IMAGE_ID" pacman -Syu --noconfirm
sudo ip netns exec "$NETNS_NAME" crun exec "$IMAGE_ID" pacman -S --noconfirm nginx

echo "Container $IMAGE_ID is running in namespace $NETNS_NAME. Access Nginx via http://10.10.10.200:80"