#!/bin/bash

# Variables
PACKAGE_NAME="nss"
PACKAGE_VERSION="3.103"
PACKAGE_TARBALL="${PACKAGE_NAME}-${PACKAGE_VERSION}.tar.gz"
PATCH_NAME="nss-3.103-standalone-1.patch"
PACKAGE_URL="https://archive.mozilla.org/pub/security/nss/releases/NSS_3_103_RTM/src/${PACKAGE_TARBALL}"
PATCH_URL="https://www.linuxfromscratch.org/patches/blfs/12.2/${PATCH_NAME}"
PACKAGE_MD5="2823082a44b9dd71d6281108e0bab03f"
INSTALL_DIR="/usr"
CURRENT_USER=$(whoami)

# Step 1: Download Sources and Patch
echo "Downloading ${PACKAGE_NAME}-${PACKAGE_VERSION} and patch..."
wget -O "${PACKAGE_TARBALL}" "${PACKAGE_URL}"
wget -O "${PATCH_NAME}" "${PATCH_URL}"

# Step 2: Verify MD5 checksum
echo "Verifying MD5 checksum..."
echo "${PACKAGE_MD5}  ${PACKAGE_TARBALL}" | md5sum -c -

# Step 3: Extract Sources
echo "Extracting ${PACKAGE_TARBALL}..."
tar -xf "${PACKAGE_TARBALL}"

# Step 4: Apply Patch
echo "Applying patch ${PATCH_NAME}..."
patch -d "${PACKAGE_NAME}-${PACKAGE_VERSION}" -Np1 -i "../${PATCH_NAME}"

# Step 5: Enter Source Directory
cd "${PACKAGE_NAME}-${PACKAGE_VERSION}/nss"

# Step 6: Build
echo "Building ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
make BUILD_OPT=1 \
  NSPR_INCLUDE_DIR=/usr/include/nspr \
  USE_SYSTEM_ZLIB=1 \
  ZLIB_LIBS=-lz \
  NSS_ENABLE_WERROR=0 \
  $([ $(uname -m) = x86_64 ] && echo USE_64=1) \
  $([ -f /usr/include/sqlite3.h ] && echo NSS_USE_SYSTEM_SQLITE=1)

# Step 7: Test (Optional)
echo "Running tests (optional)..."
cd tests
HOST=localhost DOMSUF=localdomain ./all.sh
cd ../

# Step 8: Install
echo "Installing ${PACKAGE_NAME}-${PACKAGE_VERSION}..."
cd ../dist
sudo install -v -m755 Linux*/lib/*.so /usr/lib
sudo install -v -m644 Linux*/lib/{*.chk,libcrmf.a} /usr/lib
sudo install -v -m755 -d /usr/include/nss
sudo cp -v -RL {public,private}/nss/* /usr/include/nss
sudo install -v -m755 Linux*/bin/{certutil,nss-config,pk12util} /usr/bin
sudo install -v -m644 Linux*/lib/pkgconfig/nss.pc /usr/lib/pkgconfig

# Step 9: Optional Configuration
echo "Configuring NSS (optional)..."
sudo ln -sfv ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so

# Step 10: Clean Up
echo "Cleaning up..."
cd ../../
rm -rf "${PACKAGE_NAME}-${PACKAGE_VERSION}" "${PACKAGE_TARBALL}" "${PATCH_NAME}"

echo "${PACKAGE_NAME}-${PACKAGE_VERSION} installation complete."
