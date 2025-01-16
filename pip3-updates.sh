#!/bin/bash

# Ensure pip3 is available
if ! command -v pip3 &>/dev/null; then
    echo "pip3 is not installed. Please install pip3 before running this script."
    exit 1
fi

# Define the packages and their installation order
PACKAGES=("flit-core" "wheel" "setuptools" "meson" "MarkupSafe" "Jinja2")

# Install each package in order
for PACKAGE in "${PACKAGES[@]}"; do
    echo "Installing $PACKAGE..."
    pip3 install --upgrade $PACKAGE
    if [ $? -ne 0 ]; then
        echo "Failed to install $PACKAGE. Exiting."
        exit 1
    fi
done

echo "All packages installed successfully!"
