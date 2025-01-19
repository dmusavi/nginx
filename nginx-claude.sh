#!/bin/bash

# Set strict error handling
set -euo pipefail
IFS=$'\n\t'

# Setup logging
exec 1> >(logger -s -t $(basename $0)) 2>&1

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
readonly SOCAT_PID_FILE="/var/run/socat-$IMAGE_ID.pid"

# Cleanup function
cleanup() {
    local exit_code=$?
    echo "Performing cleanup..."
    
    # Kill socat if running
    if [ -f "$SOCAT_PID_FILE" ]; then
        sudo kill "$(cat "$SOCAT_PID_FILE")" 2>/dev/null || true
        sudo rm -f "$SOCAT_PID_FILE"
    fi

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
    local deps=(ip crun sudo socat curl tar sha256sum)
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: $cmd is not installed. Please install it before running this script."
            exit 1
        fi
    done

    # Check crun version
    local crun_version
    crun_version=$(crun --version | head -n1 | awk '{print $3}')
    if ! printf '%s\n%s\n' "1.0" "$crun_version" | sort -V -C; then
        echo "Error: crun version must be at least 1.0"
        exit 1
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
        echo "Downloading Arch Linux image..."
        curl -L -o "$DOWNLOAD_DIR/$IMAGE_FILE" "$IMAGE_URL_ARCH"
        
        echo "Verifying image checksum..."
        echo "$EXPECTED_CHECKSUM $DOWNLOAD_DIR/$IMAGE_FILE" | sha256sum -c
        # Checksum verification exit temporarily disabled
        # if [ $? -ne 0 ]; then
        #     echo "Image verification failed!"
        #     exit 1
        # fi
    fi
}


# Function to create Nginx config
create_nginx_config() {
    if [ ! -f "$HOST_NGINX_CONF" ]; then
        echo "Creating default Nginx config..."
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
    fi
}

#!/usr/bin/env bash

# ... (previous parts of the script remain unchanged)

# Function to create container config
create_container_config() {
    cat << EOF > "$BUNDLE_DIR/config.json"
{
    "ociVersion": "1.0.2",
    # Specifies compliance with version 1.0.2 of the OCI runtime spec, ensuring compatibility with container runtime tools like crun.

    "process": {
        # Begins the process configuration section, detailing how the main process in the container should behave.

        "user": {"uid": 1000, "gid": 1000},
        # Sets the user ID and group ID for the process inside the container to 1000, typically corresponding to a non-root user for enhanced security.

        "args": ["/usr/bin/nginx", "-g", "daemon off;"],
        # Specifies the command to run when the container starts; here, it's Nginx with the option to not daemonize, keeping the process in the foreground.

        "env": ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "LANG=C.UTF-8"],
        # Sets environment variables for the container process. PATH ensures executables are found, LANG sets the language environment.

        "cwd": "/",
        # Sets the current working directory inside the container to the root directory.

        "capabilities": {
            "bounding": ["CAP_CHOWN", "CAP_NET_BIND_SERVICE"],
            "effective": ["CAP_CHOWN", "CAP_NET_BIND_SERVICE"]
        },
        # Grants specific Linux capabilities. CAP_CHOWN allows changing file ownership, CAP_NET_BIND_SERVICE allows binding to privileged ports like 80 for Nginx.

        "rlimits": [{"type": "RLIMIT_NOFILE", "hard": 1024, "soft": 1024}],
        # Sets resource limits for the number of open files, controlling resource usage to prevent exhaustion.

        "terminal": false
        # Indicates this container does not run interactively; no terminal is provided.

    },
    "root": {"path": "rootfs", "readonly": false},
    # Specifies where the root filesystem of the container should be ('rootfs') and that it's writable for necessary operations.

    "hostname": "arch-container",
    # Sets the hostname within the container, useful for network identification.

    "linux": {
        # Begins Linux-specific configurations.

        "namespaces": [
            {"type": "pid"},
            {"type": "mount"},
            {"type": "network", "path": "/var/run/netns/$NETNS_NAME"}
        ],
        # Defines isolation namespaces for PID, mount, and network, enhancing security by isolating these resources from the host.

        "resources": {
            "memory": {"limit": 512000000, "swap": 0},
            # Limits memory usage to 512MB, with no swap space, controlling resource allocation.

            "cpu": {"shares": 1024, "quota": 100000, "period": 100000},
            # Configures CPU time allocation, where shares, quota, and period manage CPU resource distribution.

            "pids": {"limit": 100}
            # Limits the number of processes to prevent excessive process creation.

        },
        "seccomp": {
            "defaultAction": "SCMP_ACT_ERRNO",
            # Default action for system calls not explicitly allowed is to return an error.

            "architectures": ["SCMP_ARCH_X86_64"],
            # Specifies this seccomp profile applies to x86_64 architecture.

            "syscalls": [
                {
                    "names": [
                        # Lists system calls that are explicitly allowed for security purposes.
                        "accept4", "bind", "clone", "close", "connect", "epoll_create1", "epoll_ctl", "epoll_wait",
                        "exit", "exit_group", "fstat", "futex", "getcwd", "getdents64", "getpid", "ioctl", "listen",
                        "lseek", "mkdir", "mmap", "mount", "open", "openat", "pipe2", "read", "recv", "recvfrom",
                        "rt_sigaction", "rt_sigprocmask", "rt_sigreturn", "select", "send", "sendto",
                        "set_robust_list", "set_tid_address", "socket", "stat", "write"
                    ],
                    "action": "SCMP_ACT_ALLOW"
                    # Allows these specific system calls, reducing the attack surface by blocking others by default.
                }
            ]
        }
    },
    "mounts": [
        {"destination": "/proc", "type": "proc", "source": "proc"},
        # Mounts the proc filesystem, providing processes information.

        {"destination": "/dev", "type": "tmpfs", "source": "tmpfs", "options": ["nosuid", "strictatime", "mode=755", "size=65536k"]},
        # Creates a tmpfs for /dev, ensuring devices are available but with security options to prevent SUID execution.

        {"destination": "/dev/pts", "type": "devpts", "source": "devpts", "options": ["nosuid", "noexec", "newinstance", "ptmxmode=0666", "mode=0620"]},
        # Mounts a pseudo terminal filesystem with restrictions to prevent execution and SUID.

        {"destination": "/sys", "type": "sysfs", "source": "sysfs", "options": ["nosuid", "noexec", "nodev", "ro"]},
        # Mounts sysfs read-only, providing system information without allowing modifications.

        {"destination": "/etc/nginx/nginx.conf", "source": "$HOST_NGINX_CONF", "type": "bind", "options": ["ro", "rbind"]},
        # Binds the host's Nginx config file into the container, read-only for configuration.

        {"destination": "/usr/share/nginx/html", "source": "$HOST_MEDIA_DIR", "type": "bind", "options": ["ro", "rbind"]}
        # Binds a directory for serving media content, ensuring updates on the host are reflected in the container.
    ]
}
EOF
}

# ... (rest of the script remains unchanged)

# Function to set up networking
setup_networking() {
    # Create network namespace if it doesn't exist
    if ! sudo ip netns list | grep -qw "$NETNS_NAME"; then
        echo "Creating network namespace $NETNS_NAME..."
        sudo ip netns add "$NETNS_NAME"
    fi

    # Create bridge if it doesn't exist
    if ! ip link show "$BRIDGE_NAME" &>/dev/null; then
        echo "Creating bridge $BRIDGE_NAME..."
        sudo ip link add name "$BRIDGE_NAME" type bridge
        sudo ip addr add "$BRIDGE_IP" dev "$BRIDGE_NAME"
        sudo ip link set "$BRIDGE_NAME" up
    fi

    # Create veth pair if they don't exist
    if ! ip link show veth0 &>/dev/null && ! ip link show veth1 &>/dev/null; then
        echo "Creating veth pair..."
        sudo ip link add veth0 type veth peer name veth1
        sudo ip link set veth0 netns "$NETNS_NAME"
        sudo ip link set veth1 master "$BRIDGE_NAME"
        sudo ip netns exec "$NETNS_NAME" ip addr add "$CONTAINER_IP" dev veth0
        sudo ip netns exec "$NETNS_NAME" ip link set veth0 up
        sudo ip link set veth1 up
    fi

    # Set up routing
    sudo ip netns exec "$NETNS_NAME" ip route add default via "${CONTAINER_IP%/*}"
    
    # Enable packet forwarding
    echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward >/dev/null
}

# Function to start container
start_container() {
    echo "Starting container..."
    if ! sudo ip netns exec "$NETNS_NAME" crun create --bundle "$BUNDLE_DIR" "$IMAGE_ID"; then
        echo "Failed to create container"
        exit 1
    fi
    
    if ! sudo ip netns exec "$NETNS_NAME" crun start "$IMAGE_ID"; then
        echo "Failed to start container"
        exit 1
    fi
}

# Function to set up port forwarding
setup_port_forwarding() {
    echo "Setting up port forwarding..."
    if sudo ip netns exec "$NETNS_NAME" ss -tuln | grep -qw ":$HOST_PORT "; then
        echo "Error: Port $HOST_PORT is already in use."
        exit 1
    fi
    
    nohup sudo ip netns exec "$NETNS_NAME" socat \
        TCP-LISTEN:"$HOST_PORT",fork \
        TCP:"$CONTAINER_IP":"$CONTAINER_PORT" >/dev/null 2>&1 &
    echo $! > "$SOCAT_PID_FILE"
}

# Function to install and configure Nginx
setup_nginx() {
    echo "Installing and configuring Nginx..."
    sudo ip netns exec "$NETNS_NAME" crun exec "$IMAGE_ID" pacman-key --init
    if [ $? -ne 0 ]; then
        echo "Failed to initialize pacman keys"
        exit 1
    fi
    
    sudo ip netns exec "$NETNS_NAME" crun exec "$IMAGE_ID" pacman-key --populate archlinux
    if [ $? -ne 0 ]; then
        echo "Failed to populate pacman keys"
        exit 1
    }
    
    sudo ip netns exec "$NETNS_NAME" crun exec "$IMAGE_ID" \
        pacman -Syu --noconfirm
    if [ $? -ne 0 ]; then
        echo "Failed to update system"
        exit 1
    fi
    
    sudo ip netns exec "$NETNS_NAME" crun exec "$IMAGE_ID" \
        pacman -S --noconfirm nginx
    if [ $? -ne 0 ]; then
        echo "Failed to install nginx"
        exit 1
    fi
}

# Main execution
main() {
    echo "Starting container setup..."
    check_dependencies
    create_directories
    download_verify_image
    create_nginx_config
    create_container_config
    setup_networking
    start_container
    setup_nginx
    setup_port_forwarding
    echo "Container $IMAGE_ID is running in namespace $NETNS_NAME"
    echo "Access Nginx via http://localhost:$HOST_PORT"
}

# Run main function
main

# Wait for interrupt
echo "Press Ctrl+C to stop the container and clean up"
wait
