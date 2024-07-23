#!/bin/bash

# Installation script for devopsfetch

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Function to check if a package is installed
is_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

# Function to install a package if not already installed
install_if_not_present() {
    if ! is_installed "$1"; then
        echo "Installing $1..."
        apt install -y "$1"
    else
        echo "$1 is already installed. Skipping..."
    fi
}

# Update package lists
apt update

# Install dependencies if not already present
install_if_not_present "lsof"
install_if_not_present "jq"
install_if_not_present "nginx"

# Check Docker installation
if ! command -v docker &>/dev/null; then
    echo "Docker is not installed. Installing Docker..."
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Set up the stable repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io
else
    echo "Docker is already installed. Skipping..."
fi

# Copy main script to /usr/local/bin
echo "Copying devopsfetch script to /usr/local/bin..."
cp devopsfetch.sh /usr/local/bin/devopsfetch
chmod +x /usr/local/bin/devopsfetch

# Create systemd service file
echo "Creating systemd service file..."
cat > /etc/systemd/system/devopsfetch.service <<EOL
[Unit]
Description=devopsfetch monitoring service
After=network.target

[Service]
ExecStart=/usr/local/bin/devopsfetch
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd, enable and start the service
echo "Enabling and starting devopsfetch service..."
systemctl daemon-reload
systemctl enable devopsfetch.service
systemctl start devopsfetch.service

echo "devopsfetch has been installed and service started."