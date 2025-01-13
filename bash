#!/bin/bash

# Variables for version iteration
BASH_VERSION="5.2.37"
TAR="bash-$BASH_VERSION.tar.gz"

# Step 1: Extract Bash tarball
tar -xf $TAR
cd "bash-$BASH_VERSION"

# Step 2: Prepare Bash for compilation
./configure --prefix=/usr                      \
            --build=$(sh support/config.guess) \
            --host=x86_64                      \
            --without-bash-malloc

# Step 3: Compile the package
make

# Step 4: Install the package
make install

# Step 5: Make a link for the programs that use sh for a shell
ln -sv bash /bin/sh

# Cleanup: Remove the source directory
cd ..
rm -rf "bash-$BASH_VERSION"
