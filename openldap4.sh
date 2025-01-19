#!/bin/bash

# Variables
PACKAGE_NAME="openldap"
PACKAGE_VERSION="2.6.8"
PACKAGE_TARBALL="${PACKAGE_NAME}-${PACKAGE_VERSION}.tgz"
PACKAGE_URL="https://www.openldap.org/software/download/OpenLDAP/openldap-release/${PACKAGE_TARBALL}"
PACKAGE_MD5="a7ca5f245340e478ea18b8f972c89bb1"
BUILD_DIR="."
INSTALL_DIR="/usr"
CURRENT_USER=$(whoami)

# Step 1: Download
echo "Downloading ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
wget -O "${PACKAGE_TARBALL}" "${PACKAGE_URL}"

# Step 2: Verify MD5 checksum
echo "Verifying MD5 checksum..."
echo "${PACKAGE_MD5}  ${PACKAGE_TARBALL}" | md5sum -c -

# Step 3: Remove write protection and change ownership
echo "Removing write protection and setting ownership..."
sudo chmod -R u+w "${BUILD_DIR}/${PACKAGE_TARBALL}"
sudo chown -R ${CURRENT_USER}:${CURRENT_USER} "${BUILD_DIR}/${PACKAGE_TARBALL}"

# Step 4: Extract
echo "Extracting ${PACKAGE_TARBALL}..."
tar -xzf "${PACKAGE_TARBALL}"

# Step 5: Enter Source Directory
cd "${PACKAGE_NAME}-${PACKAGE_VERSION}"

# Step 6: Configure
echo "Configuring ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
./configure --prefix=${INSTALL_DIR}         \
            --sysconfdir=/etc               \
            --localstatedir=/var            \
            --libexecdir=/usr/lib           \
            --disable-static                \
            --disable-debug                 \
            --with-tls=openssl              \
            --with-cyrus-sasl               \
            --without-systemd               \
            --enable-dynamic                \
            --enable-crypt                  \
            --enable-spasswd                \
            --enable-slapd                  \
            --enable-modules                \
            --enable-rlookups               \
            --enable-backends=mod           \
            --disable-sql                   \
            --disable-wt                    \
            --enable-overlays=mod

# Step 7: Build
echo "Building ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
make depend &&
make

# Step 8: Test
echo "Testing ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
make test

# Step 9: Install
echo "Installing ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
sudo make install

# Step 10: Clean Up
echo "Cleaning up..."
cd ..
rm -rf "${PACKAGE_NAME}-${PACKAGE_VERSION}"

echo "${PACKAGE_NAME}-${PACKAGE_VERSION} installation complete."
