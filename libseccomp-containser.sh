#!/bin/bash

# Define variables for libseccomp
LIBSECCOMP_VERSION="2.5.5"
LIBSECCOMP_TAR="libseccomp-${LIBSECCOMP_VERSION}.tar.gz"
LIBSECCOMP_MD5="c27a5e43cae1e89e6ebfedeea734c9b4"
LIBSECCOMP_URL="https://github.com/seccomp/libseccomp/releases/download/v2.5.5/${LIBSECCOMP_TAR}"

# Ensure necessary commands are available
for cmd in curl tar make sudo md5sum chown; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is not installed. Please install it before running this script."
        exit 1
    fi
done

# Download libseccomp
echo "Downloading libseccomp version ${LIBSECCOMP_VERSION}..."
curl -LO ${LIBSECCOMP_URL}

# Verify the MD5 checksum for libseccomp
echo "Verifying MD5 checksum for libseccomp..."
echo "${LIBSECCOMP_MD5} ${LIBSECCOMP_TAR}" | md5sum -c -

# Extract libseccomp
echo "Extracting ${LIBSECCOMP_TAR}..."
tar -xzf ${LIBSECCOMP_TAR}

# Change to the libseccomp source directory
cd libseccomp-${LIBSECCOMP_VERSION}
chmod -R +w . 
# Set ownership and correct permissions
echo "Setting ownership and permissions for libseccomp-${LIBSECCOMP_VERSION}..."
sudo chown -R $(whoami):$(whoami) .
sudo chmod -R u+rwX,g+rX,o+rx .

# Configure, compile, and install libseccomp with shared support
echo "Configuring libseccomp..."
./configure --prefix=/usr --disable-static --enable-shared

echo "Building libseccomp..."
make

# Run tests with parallel execution
echo "Running tests for libseccomp with -j12..."
make check -j12

echo "Installing libseccomp..."
sudo make install

# Clean up
echo "Cleaning up libseccomp..."
cd ..
rm -rf libseccomp-${LIBSECCOMP_VERSION} ${LIBSECCOMP_TAR}

echo "libseccomp ${LIBSECCOMP_VERSION} installation complete."
