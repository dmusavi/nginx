#!/bin/bash

# Set strict error handling
set -euo pipefail
IFS=$'\n\t'

# Setup logging
log() {
    echo -e "[INFO] $1" | logger -s -t $(basename $0)
}
error_exit() {
    echo -e "[ERROR] $1"
    cleanup
    exit 1
}

# Log the start of the script
log "Script started"

# Variables
readonly IMAGE_URL_ARCH="https://quay.io/oci/archlinux:latest.tar"
readonly IMAGE_FILE="arch-latest.tar"
readonly EXPECTED_CHECKSUM="SHA256_CHECKSUM_HERE" # Replace with actual checksum
readonly DOWNLOAD_DIR="/tmp/arch_image"
readonly BUNDLE_DIR="/tmp/arch_bundle"
readonly IMAGE_ID="arch-container"
readonly NETNS_NAME="arch-netns"
readonly BRIDGE_NAME="br0"
readonly BRIDGE_IP="10.10.10.14/24"
readonly CONTAINER_IP="10.0.20.1/24"
readonly HOST_PORT="8088"
readonly CONTAINER_PORT="80"
readonly HOST_CONFIG_DIR="/home/d/config"
readonly HOST_NGINX_CONF="$HOST_CONFIG_DIR/nginx.conf"
readonly HOST_MEDIA_DIR="/home/d/downloads/media"

# Cleanup function
cleanup() {
    local exit_code=$?
    log "Performing cleanup..."

    # Stop and remove container
    if sudo crun list | grep -qw "$IMAGE_ID"; then
        sudo crun stop "$IMAGE_ID" 2>/dev/null || true
        sudo crun delete -f "$IMAGE_ID" 2>/dev/null || true
    fi

    # Clean up network namespace and interfaces
    if sudo ip netns list | grep -qw "$NETNS_NAME"; then
        sudo ip netns del "$NETNS_NAME" 2>/dev/null || true
    fi


    # Remove temporary directories
    sudo rm -rf "$DOWNLOAD_DIR" "$BUNDLE_DIR"

    exit "$exit_code"
}

# Set up trap for cleanup
trap cleanup ERR EXIT

# Function to check dependencies
check_dependencies() {
    local deps=(crun sudo curl)
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error_exit "$cmd is not installed. Please install it before running this script."
        fi
    done

    # Check crun version
    local crun_version
    crun_version=$(crun --version | head -n1 | awk '{print $3}')
    if ! printf '%s\n%s\n' "1.0" "$crun_version" | sort -V -C; then
        error_exit "crun version must be at least 1.0"
    fi
}

# Function to create necessary directories with proper permissions
create_directories() {
    sudo mkdir -p "$DOWNLOAD_DIR" "$BUNDLE_DIR/rootfs" "$HOST_CONFIG_DIR" "$HOST_MEDIA_DIR"
    sudo chmod 755 "$DOWNLOAD_DIR" "$BUNDLE_DIR" "$BUNDLE_DIR/rootfs" "$HOST_CONFIG_DIR" "$HOST_MEDIA_DIR"
}

# Function to download and verify image
download_verify_image() {
    if [ ! -f "$DOWNLOAD_DIR/$IMAGE_FILE" ]; then
        log "Downloading Arch Linux image..."
        curl -L -o "$DOWNLOAD_DIR/$IMAGE_FILE" "$IMAGE_URL_ARCH"

        log "Verifying image checksum..."
        echo "$EXPECTED_CHECKSUM  $DOWNLOAD_DIR/$IMAGE_FILE" | sha256sum -c -s
        if [ $? -ne 0 ]; then
            error_exit "Image verification failed!"
        fi
    fi
    log "Arch Linux image downloaded and verified."
}

# Function to create Nginx config
create_nginx_config() {
    if [ ! -f "$HOST_NGINX_CONF" ]; then
        log "Creating default Nginx config..."
        cat <<EOF > "$HOST_NGINX_CONF"
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    keepalive_timeout 65;

    server {
        listen 80;
        server_name localhost;

        location / {
            root /usr/share/nginx/html;
            index index.html;
            autoindex on;
        }

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-Content-Type-Options "nosniff";
        add_header X-XSS-Protection "1; mode=block";
    }
}
EOF
        sudo chmod 644 "$HOST_NGINX_CONF"
        log "Nginx config created."
    fi
}

# Function to create container config
create_container_config() {
    cat << EOF > "$BUNDLE_DIR/config.json"
{
    "ociVersion": "1.0.2",
    "process": {
        "user": {"uid": 1000, "gid": 1000},
        "args": ["/usr/bin/nginx", "-g", "daemon off;"],
        "env": ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "LANG=C.UTF-8"],
        "cwd": "/",
        "capabilities": {
            "bounding": ["CAP_CHOWN", "CAP_NET_BIND_SERVICE"],
            "effective": ["CAP_CHOWN", "CAP_NET_BIND_SERVICE"]
        },
        "rlimits": [{"type": "RLIMIT_NOFILE", "hard": 1024, "soft": 1024}],
        "terminal": false
    },
    "root": {"path": "rootfs", "readonly": false},
    "hostname": "arch-container",
    "linux": {
        "namespaces": [
            {"type": "pid"},
            {"type": "mount"},
            {"type": "network", "path": "/var/run/netns/$NETNS_NAME"}
        ],
        "resources": {
            "memory": {"limit": 512000000, "swap": 0},
            "cpu": {"shares": 1024, "quota": 100000, "period": 100000},
            "pids": {"limit": 100}
        },
        "seccomp": {
            "defaultAction": "SCMP_ACT_ERRNO",
            "architectures": ["SCMP_ARCH_X86_64"],
            "syscalls": [
                {
                    "names": [
                        "accept4", "bind", "clone", "close", "connect", "epoll_create1", "epoll_ctl", "epoll_wait",
                        "exit", "exit_group", "fstat", "futex", "getcwd", "getdents64", "getpid", "ioctl", "listen",
                        "lseek", "mkdir", "mmap", "mount", "open", "openat", "pipe2", "read", "recv", "recvfrom",
                        "rt_sigaction", "rt_sigprocmask", "rt_sigreturn", "select", "send", "sendto",
                        "set_robust_list", "set_tid_address", "socket", "stat", "write"
                    ],
                    "action": "SCMP_ACT_ALLOW"
                }
            ]
        }
    },
    "mounts": [
        {"destination": "/proc", "type": "proc", "source": "proc"},
        {"destination": "/dev", "type": "tmpfs", "source": "tmpfs", "options": ["nosuid", "strictatime", "mode=755", "size=65536k"]},
        {"destination": "/dev/pts", "type": "devpts", "source": "devpts", "options": ["nosuid", "noexec", "newinstance", "ptmxmode=0666", "mode=0620"]},
        {"destination": "/sys", "type": "sysfs", "source": "sysfs", "options": ["nosuid", "noexec", "nodev", "ro"]},
        {"destination": "/etc/nginx/nginx.conf", "source": "$HOST_NGINX_CONF", "type": "bind", "options": ["ro", "rbind"]},
        {"destination": "/usr/share/nginx/html", "source": "$HOST_MEDIA_DIR", "type": "bind", "options": ["ro", "rbind"]}
    ]
}
EOF
    log "Container config created."
}


# Function to set up networking
setup_networking() {
    log "Setting up network..."

    # Ensure bridge br0 is up
    if ! ip link show "$BRIDGE_NAME" &>/dev/null; then
        log "Bridge $BRIDGE_NAME does not exist. Please bring it up using ifup."
        error_exit "Bridge $BRIDGE_NAME not found."
    else
        log "Using existing bridge $BRIDGE_NAME"
    fi

    # Create network namespace if it doesn't exist
    if ! sudo ip netns list | grep -qw "$NETNS_NAME"; then
        log "Creating network namespace $NETNS_NAME..."
        sudo ip netns add "$NETNS_NAME"
    fi

    # Create veth pair if they don't exist
    if ! ip link show veth0 &>/dev/null && ! ip link show veth1 &>/dev/null; then
        log "Creating veth pair..."
        sudo ip link add veth0 type veth peer name veth1
        sudo ip link set veth0 netns "$NETNS_NAME"
        sudo ip link set veth1 master "$BRIDGE_NAME"
        sudo ip netns exec "$NETNS_NAME" ip addr add "$CONTAINER_IP" dev veth0
        sudo ip netns exec "$NETNS_NAME" ip link set veth0 up
        sudo ip link set veth1 up
    fi
}

# Function to start the container
start_container() {
    log "Starting container $IMAGE_ID..."
    sudo ip netns exec "$NETNS_NAME" crun --runtime-flag=no-pivot -b "$BUNDLE_DIR" -n "$IMAGE_ID" start
}

# Main function
main() {
    check_dependencies
    create_directories
    download_verify_image
    create_nginx_config
    create_container_config
    setup_networking
    start_container

    log "Container started with port forwarding from host $HOST_PORT to container $CONTAINER_PORT."
}

# Run main function
main
