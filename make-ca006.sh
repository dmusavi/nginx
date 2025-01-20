#!/bin/bash
set -e  # Exit on error

# Variables
PACKAGE_NAME="make-ca"
PACKAGE_VERSION="1.14"
PACKAGE_TARBALL="${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz"
PACKAGE_URL="https://github.com/lfs-book/make-ca/archive/v1.14/make-ca-1.14.tar.gz"
PACKAGE_MD5="e99d2985ead0037caedb765fd66b33f0"
INSTALL_DIR="/usr"
LOG_FILE="/tmp/${PACKAGE_NAME}_install.log"

# Function to log messages
log() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${message}" | tee -a "$LOG_FILE"
}

# Step 1: Ensure necessary directories exist
log "Checking and creating necessary directories..."
sudo mkdir -p /etc/ssl/{certs,local} /etc/pki/{nssdb,anchors,tls/{certs,java}}

# Step 2: Download Sources
log "Downloading ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
wget -q -O "${PACKAGE_TARBALL}" "${PACKAGE_URL}"

# Step 3: Verify MD5 checksum
log "Verifying MD5 checksum..."
echo "${PACKAGE_MD5}  ${PACKAGE_TARBALL}" | md5sum -c - | tee -a "$LOG_FILE"

# Step 4: Extract Sources
log "Extracting ${PACKAGE_TARBALL}..."
tar -xf "${PACKAGE_TARBALL}"

# Step 5: Enter Source Directory
cd "${PACKAGE_NAME}-${PACKAGE_VERSION}"

# Step 6: Build and Install
log "Installing ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
sudo make install

# Step 7: Setup
log "Setting up ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
/usr/sbin/make-ca -g | tee -a "$LOG_FILE"

# Step 8: Clean Up
log "Cleaning up..."
cd ..
rm -rf "${PACKAGE_NAME}-${PACKAGE_VERSION}" "${PACKAGE_TARBALL}"

log "${PACKAGE_NAME}-${PACKAGE_VERSION} installation complete."
