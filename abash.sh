#!/bin/bash

# Variables
VERSION="5.2.37"
URL="https://ftp.gnu.org/gnu/bash/bash-${VERSION}.tar.gz"
TAR_FILE="bash-${VERSION}.tar.gz"
DIR="bash-${VERSION}"

# Download Bash
wget $URL

# Extract the tar.gz file
tar -xzf $TAR_FILE

# Change into the directory
cd $DIR

# Prepare Bash for compilation
./configure --prefix=/usr             \
            --without-bash-malloc     \
            --with-installed-readline \
            --docdir=/usr/share/doc/bash-${VERSION}

# Compile the package
make

# Prepare the tests
sudo chown -R $(whoami) .

# Run the test suite as a non-root user
su -s /usr/bin/expect $(whoami) << "EOF"
set timeout -1
spawn make tests
expect eof
lassign [wait] _ _ _ value
exit $value
EOF

# Install the package
sudo make install

# Run the newly compiled bash program (replacing the one that is currently being executed)
exec /usr/bin/bash --login

# Clean up
cd ..
rm -rf $DIR $TAR_FILE
