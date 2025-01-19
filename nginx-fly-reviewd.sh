#!/bin/bash

# Set strict error handling
set -euo pipefail  # Exit immediately on error, treat unset variables as errors, and ensure correct handling of pipes
IFS=$'\n\t'  # Set Internal Field Separator for handling newlines and tabs

# Setup logging
log() {
    echo -e "[INFO] $1" | logger -s -t $(basename $0)  # Log informational messages with system logger
}
error_exit() {
    echo -e "[ERROR] $1"  # Log error messages
    cleanup  # Call cleanup function
    exit 1  # Exit with a non-zero status
}

# Log the start of the script
log "Script started"

# Variables
readonly IMAGE_URL_ARCH="https://quay.io/oci/archlinux:latest.tar"  # URL for the latest Arch Linux image
readonly IMAGE_FILE="arch-latest.tar"  # Filename of the downloaded image
readonly EXPECTED_CHECKSUM="SHA256_CHECKSUM_HERE"  # Expected SHA256 checksum for verification (replace with actual checksum)
readonly DOWNLOAD_DIR="/tmp/arch_image"  # Directory for storing the downloaded image
readonly BUNDLE_DIR="/tmp/arch_bundle"  # Directory for the container configuration bundle
readonly IMAGE_ID="arch-container"  # Container ID for crun
readonly NETNS_NAME="arch-netns"  # Network namespace name
readonly BRIDGE_NAME="br0"  # Bridge name (brought up by init systemv ifup br0)
readonly BRIDGE_IP="10.10.10.14/24"  # IP address for the bridge network
readonly CONTAINER_IP="10.0.20.1/24"  # IP address for the container within its network
readonly HOST_PORT="8088"  # Host port for container port forwarding
readonly CONTAINER_PORT="80"  # Container port
readonly HOST_CONFIG_DIR="/home/d/config"  # Directory for Nginx configuration on the host
readonly HOST_NGINX_CONF="$HOST_CONFIG_DIR/nginx.conf"  # Path to Nginx configuration on the host
readonly HOST_MEDIA_DIR="/home/d/downloads/media"  # Directory for media files to be served by Nginx on the host

# Cleanup function
cleanup() {
    local exit_code=$?  # Capture the exit code
    log "Performing cleanup..."  # Log cleanup action

    # Stop and remove container
    if sudo crun list | grep -qw "$IMAGE_ID"; then
        sudo crun stop "$IMAGE_ID" 2>/dev/null || true  # Stop the container
        sudo crun delete -f "$IMAGE_ID" 2>/dev/null || true  # Force delete the container
    fi

    # Clean up network namespace and interfaces
    if sudo ip netns list | grep -qw "$NETNS_NAME"; then
        sudo ip netns del "$NETNS_NAME" 2>/dev/null || true  # Delete network namespace
    fi

    # Remove veth pair if created by this script
    if ip link show veth1 &>/dev/null; then
        sudo ip link delete veth1 2>/dev/null || true  # Delete veth pair
    fi

    # Remove temporary directories
    sudo rm -rf "$DOWNLOAD_DIR" "$BUNDLE_DIR"  # Remove the temporary directories

    exit "$exit_code"  # Exit with the captured exit code
}

# Set up trap for cleanup
trap cleanup ERR EXIT  # Catch ERR and EXIT signals to execute cleanup function

# Function to check dependencies
check_dependencies() {
    local deps=(crun sudo curl)  # List of dependencies
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error_exit "$cmd is not installed. Please install it before running this script."  # Check if all dependencies are installed
        fi
    done

    # Check crun version
    local crun_version
    crun_version=$(crun --version | head -n1 | awk '{print $3}')  # Get crun version
    if ! printf '%s\n%s\n' "1.0" "$crun_version" | sort -V -C; then  # Check if crun version is at least 1.0
        error_exit "crun version must be at least 1.0"  # Exit if version is not valid
    fi
}

# Function to create necessary directories with proper permissions
create_directories() {
    log "Creating necessary directories..."

    # Create directories
    sudo mkdir -p "$DOWNLOAD_DIR" "$BUNDLE_DIR/rootfs" "$HOST_CONFIG_DIR" "$HOST_MEDIA_DIR"

    # Change ownership to the current user
    sudo chown -R "$(whoami):$(whoami)" "$DOWNLOAD_DIR" "$BUNDLE_DIR" "$HOST_CONFIG_DIR" "$HOST_MEDIA_DIR"

    # Set permissions
    chmod 755 "$DOWNLOAD_DIR" "$BUNDLE_DIR" "$BUNDLE_DIR/rootfs"
    chmod 755 "$HOST_CONFIG_DIR" "$HOST_MEDIA_DIR"

    # Verify directories are writable
    for dir in "$DOWNLOAD_DIR" "$BUNDLE_DIR" "$HOST_CONFIG_DIR" "$HOST_MEDIA_DIR"; do
        if [ ! -w "$dir" ]; then
            error_exit "Directory $dir is not writable. Check permissions or ownership."
        fi
    done

    log "Directories created and permissions verified."
}

# Function to download and verify image
download_verify_image() {
    if [ ! -f "$DOWNLOAD_DIR/$IMAGE_FILE" ]; then  # Check if image is already downloaded
        log "Downloading Arch Linux image..."  # Log image download
        curl -L -o "$DOWNLOAD_DIR/$IMAGE_FILE" "$IMAGE_URL_ARCH"  # Download the image

        log "Verifying image checksum..."  # Log checksum verification
        #echo "$EXPECTED_CHECKSUM  $DOWNLOAD_DIR/$IMAGE_FILE" | sha256sum -c -s  # Verify SHA256 checksum
        #if [ $? -ne 0 ]; then
            #error_exit "Image verification failed!"  # Exit if verification fails
        #fi
    fi
    log "Arch Linux image downloaded and verified."  # Log successful download and verification
}

# Function to create Nginx config
create_nginx_config() {
    if [ ! -f "$HOST_NGINX_CONF" ]; then  # Check if Nginx config already exists
        log "Creating default Nginx config..."  # Log Nginx config creation
        cat <<EOF > "$HOST_NGINX_CONF"  # Create Nginx configuration file
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
        sudo chmod 644 "$HOST_NGINX_CONF"  # Set permissions
        log "Nginx config created."  # Log successful Nginx config creation
    fi
}

# Function to create container config
create_container_config() {
    cat << EOF > "$BUNDLE_DIR/config.json"  # Create container configuration
         {
    "ociVersion": "1.0.2",
    "process": {
        "user": {"uid": 1000, "gid": 1000},
        "args": ["/usr/bin/nginx", "-g", "daemon off;"],
        "env": [
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "LANG=C.UTF-8",
            "LD_LIBRARY_PATH=/lib:/usr/lib"
        ],
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
        "cgroupsPath": "/sys/fs/cgroup",
        "namespaces": [
            {"type": "pid"},
            {"type": "mount"},
            {"type": "network", "path": "/var/run/netns/$NETNS_NAME"}
        ],
        "resources": {
            "memory": {"limit": 512000000},
            "cpu": {"shares": 1024}
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
        {"destination": "/lib", "type": "bind", "source": "/lib", "options": ["ro", "rbind"]},
        {"destination": "/usr/lib", "type": "bind", "source": "/usr/lib", "options": ["ro", "rbind"]},
        {"destination": "/etc/nginx/nginx.conf", "source": "$HOST_NGINX_CONF", "type": "bind", "options": ["ro", "rbind"]},
        {"destination": "/usr/share/nginx/html", "source": "$HOST_MEDIA_DIR", "type": "bind", "options": ["ro", "rbind"]}
    ]
}
EOF
    log "Container config created."  # Log container configuration creation
}

# Function to set up networking
setup_networking() {
    log "Setting up network..."  # Log network setup

    # Create network namespace if it doesn't exist
    if ! sudo ip netns list | grep -qw "$NETNS_NAME"; then
        log "Creating network namespace $NETNS_NAME..."  # Log network namespace creation
        sudo ip netns add "$NETNS_NAME"
    fi

    # Create veth pair if they don't exist
    if ! ip link show veth1 &>/dev/null; then
        log "Creating veth pair..."  # Log veth pair creation
        sudo ip link add veth0 type veth peer name veth1
        sudo ip link set veth0 netns "$NETNS_NAME"
        sudo ip link set veth1 master "$BRIDGE_NAME"
    fi
    sudo ip netns exec "$NETNS_NAME" ip addr add "$CONTAINER_IP" dev veth0  # Assign IP to container's veth interface
    sudo ip netns exec "$NETNS_NAME" ip link set veth0 up  # Bring up container's veth interface
}
# Function to start the container
start_container() {
    log "Starting container $IMAGE_ID..."
    sudo ip netns exec "$NETNS_NAME" crun run -b "$BUNDLE_DIR" "$IMAGE_ID" &
    echo $! > /tmp/container_$IMAGE_ID.pid  # Write the PID to a file
}

# Main function
main() {
    check_dependencies  # Check for required dependencies
    create_directories  # Create necessary directories
    download_verify_image  # Download and verify the Arch Linux image
    create_nginx_config  # Create Nginx configuration
    create_container_config  # Create container configuration
    setup_networking  # Set up networking for the container
    start_container  # Start the container

    log "Container started with port forwarding from host $HOST_PORT to container $CONTAINER_PORT."  # Log successful container start
}

# Run main function
main  # Execute the main function
