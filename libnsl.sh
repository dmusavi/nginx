#!/bin/bash

# Variables
VERSION="2.0.1"
URL="https://github.com/thkukuk/libnsl/releases/download/v${VERSION}/libnsl-${VERSION}.tar.xz"
TAR_FILE="libnsl-${VERSION}.tar.xz"
DIR="libnsl-${VERSION}"

# Download libnsl
wget $URL

# Extract the tar.xz file
tar -xf $TAR_FILE

# Change into the directory
cd $DIR

# Configure, build, and install
./configure --sysconfdir=/etc --disable-static &&
make &&
sudo make install

# Clean up
cd ..
rm -rf $DIR $TAR_FILE
