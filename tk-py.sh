#!/bin/bash

# Variables
VERSION="8.6.15"
URL="https://downloads.sourceforge.net/tcl/tk${VERSION}-src.tar.gz"
TAR_FILE="tk${VERSION}-src.tar.gz"
DIR="tk${VERSION}"

# Download Tk
wget $URL

# Extract the tar.gz file
tar -xzf $TAR_FILE

# Change into the directory
cd $DIR/unix

# Configure, build, and install
./configure --prefix=/usr \
            --mandir=/usr/share/man \
            $([ $(uname -m) = x86_64 ] && echo --enable-64bit) &&
make &&

sed -e "s@^\(TK_SRC_DIR='\).*@\1/usr/include'@" \
    -e "/TK_B/s@='\(-L\)\?.*unix@='\1/usr/lib@" \
    -i tkConfig.sh &&

sudo make install &&
sudo make install-private-headers &&
sudo ln -v -sf wish8.6 /usr/bin/wish &&
sudo chmod -v 755 /usr/lib/libtk8.6.so

# Clean up
cd ../..
rm -rf $DIR $TAR_FILE
