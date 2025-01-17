#!/bin/bash

set -e  # Exit on errors

# Variables
CONTAINER_NAME="transmission-arch"
IMAGE_NAME="transmission-image"
HOST_PORT=9091
CONTAINER_PORT=9091
TRANSMISSION_CONFIG_DIR="/var/lib/transmission"
TRANSMISSION_DOWNLOAD_DIR="$TRANSMISSION_CONFIG_DIR/Downloads"

# Create the container
echo "Creating Arch-based container..."
podman run -it --name "$CONTAINER_NAME" --hostname "$CONTAINER_NAME" archlinux:latest /bin/bash -c "
    pacman -Syu --noconfirm &&
    pacman -S --noconfirm transmission-cli transmission-daemon
"

# Commit the container to an image
echo "Committing container to an image..."
podman commit "$CONTAINER_NAME" "$IMAGE_NAME"

# Start the container to configure Transmission
echo "Starting container to configure Transmission..."
podman start "$CONTAINER_NAME"

# Generate default Transmission settings
echo "Generating Transmission configuration..."
podman exec -it "$CONTAINER_NAME" bash -c "
    mkdir -p $TRANSMISSION_DOWNLOAD_DIR &&
    chown -R transmission:transmission $TRANSMISSION_CONFIG_DIR &&
    chmod -R 775 $TRANSMISSION_CONFIG_DIR &&
    transmission-daemon --config-dir $TRANSMISSION_CONFIG_DIR --logfile /dev/null
"

# Stop the daemon and modify settings
echo "Configuring Transmission settings..."
podman exec -it "$CONTAINER_NAME" bash -c "
    killall transmission-daemon || true
    sed -i 's/\"rpc-authentication-required\":.*/\"rpc-authentication-required\": false,/' $TRANSMISSION_CONFIG_DIR/settings.json
    sed -i 's/\"rpc-bind-address\":.*/\"rpc-bind-address\": \"0.0.0.0\",/' $TRANSMISSION_CONFIG_DIR/settings.json
    sed -i 's/\"rpc-enabled\":.*/\"rpc-enabled\": true,/' $TRANSMISSION_CONFIG_DIR/settings.json
    sed -i 's/\"rpc-host-whitelist-enabled\":.*/\"rpc-host-whitelist-enabled\": false,/' $TRANSMISSION_CONFIG_DIR/settings.json
    sed -i 's/\"rpc-port\":.*/\"rpc-port\": $CONTAINER_PORT,/' $TRANSMISSION_CONFIG_DIR/settings.json
    sed -i 's/\"rpc-whitelist-enabled\":.*/\"rpc-whitelist-enabled\": false,/' $TRANSMISSION_CONFIG_DIR/settings.json
    sed -i 's|\"download-dir\":.*|\"download-dir\": \"$TRANSMISSION_DOWNLOAD_DIR\",|' $TRANSMISSION_CONFIG_DIR/settings.json
"

# Stop and remove the temporary container
echo "Stopping container..."
podman stop "$CONTAINER_NAME"
podman rm "$CONTAINER_NAME"

# Run the container with exposed port and bind mounts
echo "Running container with port $HOST_PORT exposed..."
podman run -dit --name "$CONTAINER_NAME" -p $HOST_PORT:$CONTAINER_PORT -v $TRANSMISSION_CONFIG_DIR:$TRANSMISSION_CONFIG_DIR "$IMAGE_NAME"

# Create a systemd service for the container
echo "Creating systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/transmission-container.service > /dev/null
[Unit]
Description=Transmission Arch Container
After=network.target

[Service]
ExecStart=/usr/bin/podman start -a $CONTAINER_NAME
ExecStop=/usr/bin/podman stop -t 10 $CONTAINER_NAME
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Set permissions, enable and start the service
echo "Setting up permissions and starting systemd service..."
sudo chmod 644 /etc/systemd/system/transmission-container.service
sudo systemctl daemon-reload
sudo systemctl enable transmission-container
sudo systemctl start transmission-container

# Final message
echo "Transmission setup complete! Access the Web GUI at http://<host-ip>:$HOST_PORT/transmission/"