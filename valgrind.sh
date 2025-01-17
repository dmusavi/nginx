#!/bin/bash

# Variables
VERSION="3.24.0"
URL="https://sourceware.org/pub/valgrind/valgrind-${VERSION}.tar.bz2"
TAR_FILE="valgrind-${VERSION}.tar.bz2"
DIR="valgrind-${VERSION}"

# Download Valgrind
wget $URL

# Extract the tar.bz2 file
tar -xjf $TAR_FILE

# Change into the directory
cd $DIR

# Apply sed command to fix the documentation path
sed -i 's|/doc/valgrind||' docs/Makefile.in

# Configure, build, and install
./configure --prefix=/usr \
            --datadir=/usr/share/doc/valgrind-${VERSION} &&
make &&
sudo make install

# Optional: Run tests (this may take a long time)
# make regtest

# Clean up
cd ..
rm -rf $DIR $TAR_FILE
