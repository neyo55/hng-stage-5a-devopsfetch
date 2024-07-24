# DevOps Fetch Installation and Usage Guide

This document provides a comprehensive guide for installing and using the `devopsfetch` tool. `devopsfetch` is a server information retrieval and monitoring tool that provides insights into system performance, Docker containers, Nginx configurations, and user activity.

## Table of Contents

- [DevOps Fetch Installation and Usage Guide](#devops-fetch-installation-and-usage-guide)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
    - [Running the Installation Script](#running-the-installation-script)
  - [Usage](#usage)
    - [Command-Line Options](#command-line-options)
    - [Examples](#examples)
  - [Service Management](#service-management)
  - [Logging](#logging)
  - [Monitoring Mode](#monitoring-mode)
  - [Troubleshooting](#troubleshooting)
  - [Conclusion](#conclusion)

## Prerequisites

Before you begin, ensure you have the following:

- A Debian-based Linux distribution (e.g., Ubuntu).
- Root access to the system.
- Basic knowledge of using the terminal.

## Installation

### Running the Installation Script

1. **Download the Installation Script and the devopsfetch script**: Ensure you have the `install_devopsfetch.sh` and the `devopsfetch.sh`script on your machine.

2. **Open Terminal**: Access your terminal application.

3. **Navigate to the Script Directory**: Use the `cd` command to navigate to the directory where the script is located.
4. **Give the scripts executable permission**: Execute the following command to give the permission before running the installation script:

    ```bash
   chmod +x install_devopsfetch.sh devopsfetch.sh
   ```

5. **Run the Script as Root**: Execute the following command to run the installation script:

   ```bash
   sudo bash install_devopsfetch.sh
   ```
   or 

   ```bash
   sudo ./install_devopsfetch.sh
   ```

   The script will:
   - Check for root privileges.
   - Update package lists.
   - Install required packages (`lsof`, `jq`, `nginx`).
   - Install Docker if not already present.
   - Copy the main `devopsfetch.sh` script to `/usr/local/bin`.
   - Create a systemd service for `devopsfetch`.

6. **Completion Message**: Upon successful installation, you will see a message indicating that `devopsfetch` has been installed and the service has started.

## Usage

After installation, you can use `devopsfetch` directly from the command line.

### Command-Line Options

The `devopsfetch` tool supports the following options:

- `monitor`: Run in continuous monitoring mode.
- `-p, --port [PORT]`: Display active ports or information about a specific port.
- `-d, --docker [CONTAINER]`: List Docker images/containers or information about a specific container.
- `-n, --nginx [DOMAIN]`: Display Nginx domains or configuration for a specific domain.
- `-u, --users [USER]`: List users and last login times or information about a specific user.
- `-t, --time START END`: Display activities within a specified time range.
- `-h, --help`: Display help message.
- `--create-service`: Create and start a systemd service for `devopsfetch`.

### Examples

Here are some examples of how to use `devopsfetch`:

- **Run in Continuous Monitoring Mode**:
  ```bash
  devopsfetch monitor
  ```

- **List All Active Ports**:
  ```bash
  devopsfetch -p
  ```

- **Show Details for Port 22**:
  ```bash
  devopsfetch -p 22
  ```

- **List All Docker Images and Containers**:
  ```bash
  devopsfetch -d
  ```

- **Show Details for a Specific Docker Container**:
  ```bash
  devopsfetch -d my_container
  ```

- **List All Nginx Domains**:
  ```bash
  devopsfetch -n
  ```

- **Show Nginx Configuration for a Specific Domain**:
  ```bash
  devopsfetch -n contoso.com
  ```

- **List All Users and Last Login Times**:
  ```bash
  devopsfetch -u
  ```

- **Show Details for a Specific User**:
  ```bash
  devopsfetch -u amaka
  ```

- **Display Activities in a Specified Time Range**:
  ```bash
  devopsfetch -t '2024-01-01 00:00:00' '2024-01-31 00:00:00'
  ```

## Service Management

`devopsfetch` runs as a systemd service, which means you can manage it using standard systemd commands:

- **Check Service Status**:
  ```bash
  systemctl status devopsfetch.service
  ```

- **Stop the Service**:
  ```bash
  systemctl stop devopsfetch.service
  ```

- **Start the Service**:
  ```bash
  systemctl start devopsfetch.service
  ```

- **Restart the Service**:
  ```bash
  systemctl restart devopsfetch.service
  ```

- **Enable the Service to Start on Boot**:
  ```bash
  systemctl enable devopsfetch.service
  ```

- **Disable the Service from Starting on Boot**:
  ```bash
  systemctl disable devopsfetch.service
  ```

## Logging

The `devopsfetch` tool is configured to log its output to both the terminal and a log file located at `/tmp/devopsfetch.log`. You can view the logs using:

```bash
cat /tmp/devopsfetch.log
```

For persistent logging, the script configures `systemd-journald` to retain logs in `/var/log/journal`.

## Monitoring Mode

In monitoring mode, `devopsfetch` continuously checks the system's status and outputs information about active ports, Docker containers, Nginx configurations, and user activity every 240 seconds. You can exit monitoring mode by pressing `Ctrl+C`.

## Troubleshooting

- **Permission Issues**: Ensure you run the script as root or with `sudo`.
- **Docker Not Running**: If you encounter issues with Docker commands, ensure that the Docker daemon is running:
  ```bash
  systemctl start docker
  ```

- **Service Not Starting**: Check the service status for errors:
  ```bash
  systemctl status devopsfetch.service
  ```

## Conclusion

You have now successfully installed and configured `devopsfetch`. This tool will help you monitor your server's performance and manage Docker containers and Nginx configurations efficiently. 

