#!/bin/bash

# Variables
IMAGE_URL_ARCH="https://quay.io/oci/archlinux:latest.tar"
IMAGE_FILE="arch-latest.tar"
DOWNLOAD_DIR="/tmp/arch_image"
BUNDLE_DIR="/tmp/arch_bundle"
IMAGE_ID="arch-container"
NETNS_NAME="arch-netns"
BRIDGE_NAME="br0"
BRIDGE_IP="10.10.10.14/24"
CONTAINER_IP="10.0.20.1/24"
HOST_PORT="8088"
CONTAINER_PORT="80"
HOST_CONFIG_DIR="/home/d/config"
HOST_NGINX_CONF="$HOST_CONFIG_DIR/nginx.conf"
HOST_MEDIA_DIR="/home/d/downloads/media"

# Ensure necessary commands are available
for cmd in ip crun sudo socat curl tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is not installed. Please install it before running this script."
        exit 1
    fi
done

# Create necessary directories
mkdir -p "$DOWNLOAD_DIR" "$BUNDLE_DIR/rootfs" "$HOST_CONFIG_DIR" "$HOST_MEDIA_DIR"

# Check if the container already exists
if sudo crun list | grep -qw "$IMAGE_ID"; then
    echo "Error: Container $IMAGE_ID already exists."
    exit 1
fi

# Download Arch Linux image
if [ ! -f "$DOWNLOAD_DIR/$IMAGE_FILE" ]; then
    echo "Downloading Arch Linux image..."
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

# Create config.json
echo "Creating config.json..."
cat <<EOF > "$BUNDLE_DIR/config.json"
{
  "ociVersion": "1.0.2",
  "process": {
    "args": ["/usr/bin/nginx", "-g", "daemon off;"],
    "env": [
      "PATH=/usr/local/bin:/usr/bin:/bin",
      "LANG=C.UTF-8"
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
      {"type": "network", "path": "/var/run/netns/$NETNS_NAME"}
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

# Create and configure the network namespace if it doesn't exist
if sudo ip netns list | grep -qw "$NETNS_NAME"; then
    echo "Network namespace $NETNS_NAME already exists."
else
    echo "Creating network namespace $NETNS_NAME..."
    sudo ip netns add "$NETNS_NAME"
fi

# Create veth pair if they don't exist
if ip link show veth0 &> /dev/null || ip link show veth1 &> /dev/null; then
    echo "veth0 or veth1 already exist."
else
    echo "Creating veth pair..."
    sudo ip link add veth0 type veth peer name veth1
fi

# Move veth0 to the namespace
if ip netns exec "$NETNS_NAME" ip link show veth0 &> /dev/null; then
    echo "veth0 is already in the namespace."
else
    sudo ip link set veth0 netns "$NETNS_NAME"
fi

# Set up veth1 and br0 if not already configured
if sudo ip link show veth1 &> /dev/null && sudo ip link show "$BRIDGE_NAME" &> /dev/null; then
    echo "veth1 or $BRIDGE_NAME already exist and configured."
else
    sudo ip link set veth1 master "$BRIDGE_NAME"
    sudo ip netns exec "$NETNS_NAME" ip addr add "$CONTAINER_IP" dev veth0
    sudo ip netns exec "$NETNS_NAME" ip link set veth0 up
    sudo ip link set veth1 up

    # Assign IP to the bridge and bring it up
    sudo ip addr add "$BRIDGE_IP" dev "$BRIDGE_NAME"
    sudo ip link set "$BRIDGE_NAME" up
fi

# Set up the routing for the container if not already configured
if sudo ip netns exec "$NETNS_NAME" ip route show | grep -qw "default via 10.0.20.1"; then
    echo "Routing already set up in the namespace."
else
    sudo ip netns exec "$NETNS_NAME" ip route add default via "10.0.20.1"
fi

# Enable packet forwarding in the host
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" -eq 0 ]; then
    echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
else
    echo "Packet forwarding is already enabled."
fi

# Start the container inside the namespace
echo "Starting the container..."
sudo ip netns exec "$NETNS_NAME" crun create --bundle "$BUNDLE_DIR" "$IMAGE_ID"
sudo ip netns exec "$NETNS_NAME" crun start "$IMAGE_ID"

# Install and configure Nginx inside the container
echo "Installing Nginx inside the container..."
sudo ip netns exec "$NETNS_NAME" crun exec "$IMAGE_ID" pacman-key --init
sudo ip netns exec "$NETNS_NAME" crun exec "$IMAGE_ID" pacman-key --populate archlinux
sudo ip netns exec "$NETNS_NAME" crun exec "$IMAGE_ID" pacman -Syu --noconfirm
sudo ip netns exec "$NETNS_NAME" crun exec "$IMAGE_ID" pacman -S --noconfirm nginx

# Use socat within the namespace to forward ports
echo "Setting up port forwarding with socat..."
if sudo ip netns exec "$NETNS_NAME" ss -tuln | grep -qw ":$HOST_PORT "; then
    echo "Error: Port $HOST_PORT is already in use."
    exit 1
else
    sudo ip netns exec "$NETNS_NAME" socat TCP-LISTEN:$HOST_PORT,fork TCP:$CONTAINER_IP:$CONTAINER_PORT
fi

echo "Container $IMAGE_ID is running in namespace $NETNS_NAME. Access Nginx via http://<host-ip>:8088"