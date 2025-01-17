#!/bin/bash

# Variables
VERSION="1.3.6"
URL="https://downloads.sourceforge.net/libtirpc/libtirpc-${VERSION}.tar.bz2"
TAR_FILE="libtirpc-${VERSION}.tar.bz2"
DIR="libtirpc-${VERSION}"

# Download libtirpc
wget $URL

# Extract the tar.bz2 file
tar -xjf $TAR_FILE

# Change into the directory
cd $DIR

# Configure, build, and install
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --disable-static \
            --disable-gssapi &&
make &&
sudo make install

# Clean up
cd ..
rm -rf $DIR $TAR_FILE
