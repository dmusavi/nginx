# Use Debian as the base image
FROM debian:latest

# Install Transmission dependencies
RUN apt-get update && apt-get install -y transmission-daemon

# Copy configuration files
COPY transmission-config /etc/transmission-daemon

# Expose Transmission ports
EXPOSE 9091 51413

# Run Transmission daemon
CMD ["transmission-daemon", "-f", "--log-error"]
