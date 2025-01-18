#!/bin/bash

# Define variables
LIBNL_VERSION="3.11.0"
LIBNL_TAR="libnl-${LIBNL_VERSION}.tar.gz"
LIBNL_MD5="0a5eb82b494c411931a47638cb0dba51"
LIBNL_URL="https://github.com/thom311/libnl/releases/download/libnl3_11_0/${LIBNL_TAR}"
LIBNL_DOC_TAR="libnl-doc-${LIBNL_VERSION}.tar.gz"
LIBNL_DOC_MD5="5c74044c92f2eb08de69cce88714cd1b"

# Download libnl
echo "Downloading libnl version ${LIBNL_VERSION}..."
curl -LO ${LIBNL_URL}

# Verify the MD5 checksum
echo "Verifying MD5 checksum..."
echo "${LIBNL_MD5} ${LIBNL_TAR}" | md5sum -c -

# Extract libnl
echo "Extracting libnl..."
tar -xzf ${LIBNL_TAR}

# Change to the libnl source directory
cd libnl-${LIBNL_VERSION}
chmod -R +w . 

# Set ownership and correct permissions
echo "Setting ownership and permissions for libnl-${LIBNL_VERSION}..."
sudo chown -R $(whoami):$(whoami) .
sudo chmod -R u+rwX,g+rX,o+rx .

# Configure, compile, and install libnl
echo "Configuring libnl..."
./configure --prefix=/usr --sysconfdir=/etc --enable-shared --disable-static

echo "Building libnl..."
make

# Run tests if needed
make check

# Install libnl
echo "Installing libnl..."
sudo make install

# Optional: Install API documentation
echo "Installing API documentation..."
mkdir -vp /usr/share/doc/libnl-${LIBNL_VERSION}
sudo tar -xf ../${LIBNL_DOC_TAR} --strip-components=1 --no-same-owner -C /usr/share/doc/libnl-${LIBNL_VERSION}

# Clean up
echo "Cleaning up..."
cd ..
rm -rf libnl-${LIBNL_VERSION} ${LIBNL_TAR}

echo "libnl ${LIBNL_VERSION} installation complete."
