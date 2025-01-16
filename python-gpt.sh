#!/bin/bash

# Define variables
PYTHON_VERSION="3.12.7"
DOWNLOAD_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz"
MD5SUM="c6c933c1a0db52597cb45a7910490f93"
DOC_DOWNLOAD_URL="https://www.python.org/ftp/python/doc/${PYTHON_VERSION}/python-${PYTHON_VERSION}-docs-html.tar.bz2"
DOC_MD5SUM="2fbda851be0e4d4c4dad7bb8d1ff7e50"
#BUILD_DIR="/tmp/python-${PYTHON_VERSION}"
INSTALL_DIR="/usr"
DOC_INSTALL_DIR="/usr/share/doc/python-${PYTHON_VERSION}/html"

# Download Python source
echo "Downloading Python ${PYTHON_VERSION} from ${DOWNLOAD_URL}"
wget ${DOWNLOAD_URL} -O Python-${PYTHON_VERSION}.tar.xz

# Verify MD5 checksum
echo "Verifying MD5 checksum"
echo "${MD5SUM}  Python-${PYTHON_VERSION}.tar.xz" | md5sum -c -

# Extract the tarball
echo "Extracting Python source"
tar -xvf Python-${PYTHON_VERSION}.tar.xz

# Change to the source directory
cd Python-${PYTHON_VERSION}

# Set C++ compiler
export CXX="/usr/bin/g++"

# Configure Python
echo "Configuring Python"
./configure --prefix=${INSTALL_DIR} \
            --enable-shared \
            --with-system-expat \
            --enable-optimizations

# Build Python
echo "Building Python"
make

# Run tests
echo "Running tests with timeout 120 seconds"
make test TESTOPTS="--timeout 120"

# Install Python
echo "Installing Python"
make install

# Install documentation if required
#echo "Installing Python documentation"
#wget ${DOC_DOWNLOAD_URL} -O python-${PYTHON_VERSION}-docs-html.tar.bz2
#echo "Verifying MD5 checksum for documentation"
#echo "${DOC_MD5SUM}  python-${PYTHON_VERSION}-docs-html.tar.bz2" | md5sum -c -

# Extract documentation
#tar --strip-components=1 -C ${DOC_INSTALL_DIR} -xvf python-${PYTHON_VERSION}-docs-html.tar.bz2

# Create symlink for version-independent documentation
#echo "Creating symlink for documentation"
#ln -svfn python-${PYTHON_VERSION} /usr/share/doc/python-3

# Set PYTHONDOCS environment variable
#echo "Setting PYTHONDOCS environment variable"
#export PYTHONDOCS=${DOC_INSTALL_DIR}

echo "Python ${PYTHON_VERSION} installation complete."
