#!/bin/bash

# Exit on error
set -e

# Log file for operations
LOG_FILE="/var/log/syslog"

# Function to log messages with different log levels, only for KERNEL functions
log() {
    local level=$1
    local message=$2
    case "$level" in
        "KERNEL")
            echo "$(date '+%Y-%m-%d %H:%M:%S') - [$level] - $message" | logger -t kernel_install
            ;;
        *)
            ;;
    esac
}

# Cleanup trap for error handling and cleanup
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log "KERNEL" "Script failed with exit code $exit_code"
    fi
    log "KERNEL" "Cleaning up temporary files..."
    rm -rf "$KERNEL_ARCHIVE" "$KERNEL_DIR" "$CHECKSUM_FILE" "${KERNEL_ARCHIVE}.sig"
}
trap cleanup EXIT

# Check if script is run as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "KERNEL" "This script must be run as root"
        exit 1
    fi
}

# Function to handle script exit with custom messages
exit_with_message() {
    local message=$1
    log "KERNEL" "$message"
    echo "$message"
    exit 1
}

# Check if a dependency is installed
check_dependency() {
    local dep=$1
    if ! command -v "$dep" &> /dev/null; then
        log "KERNEL" "$dep is not installed."
        missing_deps+=("$dep")
    fi
}

# Verify dependencies
check_dependencies() {
    missing_deps=()
    for dep in "${DEPENDENCIES[@]}"; do
        check_dependency "$dep"
    done

    if [ "${#missing_deps[@]}" -gt 0 ]; then
        exit_with_message "Missing dependencies: ${missing_deps[*]}"
    fi
}

# Adjust kernel features
adjust_kernel_features_bulk() {
    local features=("$@")
    local value=$1
    shift
    for feature in "${features[@]}"; do
        if grep -q "^$feature=" .config; then
            sed -i "s/^$feature=.*/$feature=$value/" .config
        else
            echo "$feature=$value" >> .config
        fi
    done
}

# Verify compilation output
verify_compilation() {
    local required_files=(
        "arch/x86/boot/bzImage"
        "System.map"
        ".config"
    )

    missing_files=()
    log "KERNEL" "Verifying compilation output files..."
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log "KERNEL" "Missing required file: $file"
            missing_files+=("$file")
        fi
    done

    if [ "${#missing_files[@]}" -gt 0 ]; then
        exit_with_message "Compilation failed: Missing files: ${missing_files[*]}"
    fi
}

# Kernel configuration variables
initialize_variables() {
    KERNEL_VERSION="6.12.11"  # Update here to change kernel version
    KERNEL_BASE_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x"
    KERNEL_ARCHIVE="linux-${KERNEL_VERSION}.tar.xz"
    KERNEL_DIR="linux-${KERNEL_VERSION}"
    PREV_CONFIG="/boot/config-$(uname -r)"
    GRUB_CUSTOM="/etc/grub.d/40custom"
    BOOT_DIR="/boot"
    CHECKSUM_FILE="sha256sums.asc"

    DEPENDENCIES=("wget" "tar" "make" "gpg")

    CRITICAL_FEATURES=(
        "CONFIG_VGA_CONSOLE"
        "CONFIG_FRAMEBUFFER_CONSOLE"
        "CONFIG_NVME_CORE"
        "CONFIG_KVM"
        "CONFIG_NET_NS"
        "CONFIG_BRIDGE"
        "CONFIG_BRIDGE_NETFILTER"
        "CONFIG_STP"
    )

    DISABLED_FEATURES=(
        "CONFIG_IPV6"
        "CONFIG_IP_MULTICAST"
        "CONFIG_WERROR"
        "CONFIG_PSI_DEFAULT_DISABLED"
        "CONFIG_IKHEADERS"
        "CONFIG_EXPERT"
        "CONFIG_UEVENT_HELPER"
        "CONFIG_M386"
        "CONFIG_M486"
        "CONFIG_M586"
        "CONFIG_M686"
    )
}

# Download kernel source and verify
fetch_and_verify_kernel() {
    log "KERNEL" "Downloading Linux kernel ${KERNEL_VERSION}..."
    wget "$KERNEL_BASE_URL/linux-${KERNEL_VERSION}.tar.xz" -O "$KERNEL_ARCHIVE"
    wget "$KERNEL_BASE_URL/linux-${KERNEL_VERSION}.tar.sign" -O "${KERNEL_ARCHIVE}.sig"
    wget "$KERNEL_BASE_URL/sha256sums.asc" -O "$CHECKSUM_FILE"

    log "KERNEL" "Verifying kernel archive checksum..."
    if ! grep "$KERNEL_ARCHIVE" "$CHECKSUM_FILE" | sha256sum -c -; then
        exit_with_message "Checksum verification failed for kernel archive."
    fi

    if ! gpg --list-keys 647F28654894E3BD457199BE38DBBDC86092693E &>/dev/null; then
        log "KERNEL" "Importing kernel.org public key..."
        if ! gpg --keyserver hkps://keys.openpgp.org --recv-keys 647F28654894E3BD457199BE38DBBDC86092693E; then
            exit_with_message "Error importing kernel.org public key."
        fi
    fi

    log "KERNEL" "Verifying GPG signature..."
    if ! gpg --verify "${KERNEL_ARCHIVE}.sig" "$KERNEL_ARCHIVE"; then
        exit_with_message "GPG signature verification failed for kernel archive."
    fi
}

# Extract kernel source and configure
extract_and_configure_kernel() {
    log "KERNEL" "Extracting Linux kernel..."
    tar -xf "$KERNEL_ARCHIVE"
    cd "$KERNEL_DIR"

    log "KERNEL" "Cleaning the kernel source tree..."
    make mrproper

    if [ -f "$PREV_CONFIG" ]; then
        log "KERNEL" "Merging previous configuration..."
        cp -v "$PREV_CONFIG" .config
        make olddefconfig

        adjust_kernel_features_bulk "y" "${CRITICAL_FEATURES[@]}"
        adjust_kernel_features_bulk "" "${DISABLED_FEATURES[@]}"  # Remove disabled features
    else
        exit_with_message "Previous kernel configuration not found at $PREV_CONFIG. Exiting."
    fi
}

# Compile and install kernel
compile_and_install_kernel() {
    log "KERNEL" "Compiling the kernel..."
    if ! make -j$(nproc); then
        exit_with_message "Kernel compilation failed."
    fi
    verify_compilation

    log "KERNEL" "Installing kernel modules..."
    make modules_install

    log "KERNEL" "Installing the kernel..."
    cp -iv "arch/x86/boot/bzImage" "$BOOT_DIR/vmlinuz-${KERNEL_VERSION}"
    cp -iv "System.map" "$BOOT_DIR/System.map-${KERNEL_VERSION}"
    cp -iv ".config" "$BOOT_DIR/config-${KERNEL_VERSION}"
}

# Update GRUB configuration
update_grub() {
    if [ ! -f "$GRUB_CUSTOM" ]; then
        exit_with_message "Custom GRUB configuration file $GRUB_CUSTOM does not exist. Exiting."
    fi

    if grep -q "menuentry 'SELinux'" "$GRUB_CUSTOM"; then
        sed -i "/menuentry 'SELinux'/,/}/s|vmlinuz-.*|vmlinuz-${KERNEL_VERSION}|g" "$GRUB_CUSTOM"
    else
        exit_with_message "SELinux menu entry not found in $GRUB_CUSTOM. Exiting."
    fi

    log "KERNEL" "Updating GRUB configuration..."
    if ! grub-mkconfig -o "$BOOT_DIR/grub/grub.cfg"; then
        exit_with_message "Failed to update GRUB configuration. Please check the GRUB setup."
    fi
}

# Main script execution
main() {
    initialize_variables
    check_root
    check_dependencies
    fetch_and_verify_kernel
    extract_and_configure_kernel
    compile_and_install_kernel
    update_grub
}

main "$@"
