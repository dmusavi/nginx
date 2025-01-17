#!/bin/bash

# Variables
VERSION="3470200"
URL="https://sqlite.org/2024/sqlite-autoconf-${VERSION}.tar.gz"
TAR_FILE="sqlite-autoconf-${VERSION}.tar.gz"
DIR="sqlite-autoconf-${VERSION}"

# Download SQLite without docs
wget $URL

# Extract the tar.gz file
tar -xzf $TAR_FILE

# Change into the directory
cd $DIR

# Configure, build, and install
./configure --prefix=/usr     \
            --disable-static  \
            --enable-fts{4,5} \
            CPPFLAGS="-D SQLITE_ENABLE_COLUMN_METADATA=1 \
                      -D SQLITE_ENABLE_UNLOCK_NOTIFY=1   \
                      -D SQLITE_ENABLE_DBSTAT_VTAB=1     \
                      -D SQLITE_SECURE_DELETE=1" &&
make &&
sudo make install

# Clean up
cd ..
rm -rf $DIR $TAR_FILE
