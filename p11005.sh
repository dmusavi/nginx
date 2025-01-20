#!/bin/bash

# Variables
PACKAGE_NAME="p11-kit"
PACKAGE_VERSION="0.25.5"
PACKAGE_TARBALL="${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.xz"
PACKAGE_URL="https://github.com/p11-glue/p11-kit/releases/download/0.25.5/${PACKAGE_TARBALL}"
PACKAGE_MD5="e9c5675508fcd8be54aa4c8cb8e794fc"
INSTALL_DIR="/usr"
CURRENT_USER=$(whoami)

# Step 1: Download Sources
echo "Downloading ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
wget -O "${PACKAGE_TARBALL}" "${PACKAGE_URL}"

# Step 2: Verify MD5 checksum
echo "Verifying MD5 checksum..."
echo "${PACKAGE_MD5}  ${PACKAGE_TARBALL}" | md5sum -c -

# Step 3: Extract Sources
echo "Extracting ${PACKAGE_TARBALL}..."
tar -xf "${PACKAGE_TARBALL}"

# Step 4: Enter Source Directory
cd "${PACKAGE_NAME}-${PACKAGE_VERSION}"

# Step 5: Build
echo "Building ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
mkdir p11-build &&
cd    p11-build &&
meson setup ..            \
      --prefix=/usr       \
      --buildtype=release &&
ninja

# Step 6: Test (Optional)
echo "Running tests (optional)..."
LC_ALL=C ninja test

# Step 7: Install
echo "Installing ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
sudo ninja install &&
sudo ln -sfv /usr/libexec/p11-kit/trust-extract-compat /usr/bin/update-ca-certificates

# Step 8: Clean Up
echo "Cleaning up..."
cd ..
rm -rf "${PACKAGE_NAME}-${PACKAGE_VERSION}" "${PACKAGE_TARBALL}"

echo "${PACKAGE_NAME}-${PACKAGE_VERSION} installation complete."
