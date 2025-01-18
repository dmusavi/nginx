#!/bin/bash

# Variables
IMAGE_ID="arch-latest-container"
NETNS_NAME="arch-netns"
BRIDGE_NAME="br0"
BRIDGE_IP="10.10.10.14/24"
CONTAINER_IP="10.0.20.1/24"
HOST_PORT="8088"
CONTAINER_PORT="80"

# Ensure necessary commands are available
for cmd in ip crun sudo socat; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is not installed. Please install it before running this script."
        exit 1
    fi
done

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

# Start the container inside the namespace
echo "Starting the container..."
sudo ip netns exec "$NETNS_NAME" crun run "$IMAGE_ID"

# Use socat within the namespace to forward ports
echo "Setting up port forwarding with socat..."
sudo ip netns exec "$NETNS_NAME" socat TCP-LISTEN:$HOST_PORT,fork TCP:$CONTAINER_IP:$CONTAINER_PORT

echo "Container $IMAGE_ID is running in namespace $NETNS_NAME. Access Nginx via http://<host-ip>:8088"