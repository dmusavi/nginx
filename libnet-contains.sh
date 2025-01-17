#!/bin/bash

# Define variables for libnet
LIBNET_VERSION="1.3"
LIBNET_TAR="libnet-${LIBNET_VERSION}.tar.gz"
LIBNET_MD5="d41d8cd98f00b204e9800998ecf8427e"
LIBNET_URL="https://github.com/libnet/libnet/releases/tag/v${LIBNET_VERSION}/libnet-${LIBNET_VERSION}.tar.gz"

# Download libnet
echo "Downloading libnet version ${LIBNET_VERSION}..."
curl -LO ${LIBNET_URL}

# Verify the MD5 checksum for libnet
echo "Verifying MD5 checksum for libnet..."
echo "${LIBNET_MD5} ${LIBNET_TAR}" | md5sum -c -

# Extract libnet
echo "Extracting ${LIBNET_TAR}..."
tar -xzf ${LIBNET_TAR}

# Change to the libnet source directory
cd libnet-${LIBNET_VERSION}

# Set ownership and correct permissions
echo "Setting ownership and permissions for libnet-${LIBNET_VERSION}..."
sudo chown -R $(whoami):$(whoami) .
sudo chmod -R u+rwX,g+rX,o+rx .

# Configure, compile, and install libnet
echo "Configuring libnet..."
./configure --prefix=/usr --disable-static

echo "Building libnet..."
make

# Install libnet
echo "Installing libnet..."
sudo make install

# Clean up
echo "Cleaning up libnet..."
cd ..
rm -rf libnet-${LIBNET_VERSION} ${LIBNET_TAR}

echo "libnet ${LIBNET_VERSION} installation complete."