#!/bin/bash

# Variables
VERSION="15.2"
URL="https://ftp.gnu.org/gnu/gdb/gdb-${VERSION}.tar.xz"
TAR_FILE="gdb-${VERSION}.tar.xz"
DIR="gdb-${VERSION}"

# Download GDB
wget $URL

# Extract the tar.xz file
tar -xf $TAR_FILE

# Change into the directory
cd $DIR

# Create build directory
mkdir build &&
cd build

# Configure, build, and install
../configure --prefix=/usr          \
             --with-system-readline \
             --with-python=/usr/bin/python3 &&
make &&
sudo make -C gdb install &&
sudo make -C gdbserver install

# Clean up
cd ../..
rm -rf $DIR $TAR_FILE
