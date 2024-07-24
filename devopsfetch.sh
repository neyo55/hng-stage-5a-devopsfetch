#!/bin/bash

# Configure journald to retain logs persistently
# Create the directory for the journal logs if it doesn't exist
sudo mkdir -p /var/log/journal

# Set ownership of the journal directory to root and the systemd-journal group
sudo chown root:systemd-journal /var/log/journal

# Set permissions for the journal directory
sudo chmod 2755 /var/log/journal

# Restart the systemd journald service to apply changes
sudo systemctl restart systemd-journald

# Redirect all output (stdout and stderr) to both the terminal and a log file
exec > >(tee -a /tmp/devopsfetch.log) 2>&1

# Log the start time of the script
echo "Script started at $(date)"

# Log the argument passed to the script
echo "Running with argument: $1"

# devopsfetch - Server Information Retrieval and Monitoring Tool

# Function to display help information for using devopsfetch
display_help() {
    echo "Usage: devopsfetch [OPTION]... [ARGUMENT]..."
    echo "Retrieve and display server information."
    echo "  --create-service      Create and start a systemd service for DevOps Fetch"
    echo
    echo "Options:"
    echo "  monitor               Run in continuous monitoring mode"
    echo "  -p, --port [PORT]     Display active ports or info about a specific port"
    echo "  -d, --docker [CONTAINER] List Docker images/containers or info about a specific container"
    echo "  -n, --nginx [DOMAIN]  Display Nginx domains or config for a specific domain"
    echo "  -u, --users [USER]    List users and last login times or info about a specific user"
    echo "  -t, --time START END  Display activities within a specified time range"
    echo "  -h, --help            Display this help message"
    echo
    echo "Examples:"
    echo "  devopsfetch monitor            # Run in continuous monitoring mode"
    echo "  devopsfetch -p                 # List all active ports"
    echo "  devopsfetch -p 22              # Show details for port 22"
    echo "  devopsfetch -d                 # List all Docker images and containers"
    echo "  devopsfetch -d my_container    # Show details for 'my_container'"
    echo "  devopsfetch -n                 # List all Nginx domains"
    echo "  devopsfetch -n contoso.com     # Show Nginx config for contoso.com"
    echo "  devopsfetch -u                 # List all users and last login times"
    echo "  devopsfetch -u amaka           # Show details for user 'amaka'"
    echo "  devopsfetch -t '2024-01-01 00:00:00' '2024-01-31 00:00:00'  # Show activities in January 2024"
}

# Function to format output as a table
format_table() {
    local header="$1"  # Store the header for the table
    shift  # Shift arguments to remove the header
    (echo "$header"; cat) | column -t -s $'\t' | sed '2s/[^-]/-/g'  # Format the output into a table
}

# Function to display port information
display_ports() {
    if [ -z "$1" ]; then  # Check if no specific port is provided
        echo "Active Ports and Services:"
        # Retrieve active ports and their corresponding services
        (echo -e "Port\tService"; ss -tuln | awk 'NR>1 {print $5}' | awk -F: '{print $NF}' | sort -n | uniq | \
        while read port; do
            service=$(lsof -i :$port | awk 'NR==2 {print $1}')  # Get the service name for the port
            echo -e "$port\t$service"  # Print the port and service
        done) | format_table "Port Service"  # Format the output as a table
    else
        echo "Details for port $1:"
        lsof -i :$1  # Show details for the specified port
    fi
}

# Function to display Docker information
display_docker() {
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed or not in PATH"
        return 1  # Exit the function with an error 
    fi

    # Check if the Docker daemon is running
    if ! docker info &> /dev/null; then
        echo "Error: Docker daemon is not running"
        return 1  # Exit the function with an error 
    fi

    if [ -z "$1" ]; then  # Check if no specific container is provided
        echo "Docker Images (showing latest 15):"
        # List Docker images with specific formatting
        (docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | head -n 16 | \
        awk 'NR==1 {print} NR>1 {printf "%-40s\t%-15s\t%-12s\t%-20s\t%s\n", substr($1,1,40), substr($2,1,15), substr($3,1,12), substr($4,1,20), $5}') | \
        column -t -s $'\t' | sed '2s/[^-]/-/g'  # Format the output as a table
        echo

        echo "Docker Containers (showing latest 10):"
        # List Docker containers with specific formatting
        (docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Command}}\t{{.CreatedAt}}\t{{.Status}}\t{{.Ports}}\t{{.Names}}" | head -n 11 | \
        awk 'NR==1 {print} NR>1 {printf "%-12s\t%-25s\t%-30s\t%-20s\t%-20s\t%-20s\t%s\n",
            $1,
            substr($2,1,25),
            substr($3,1,30),
            substr($4,1,20),
            substr($5,1,20),
            substr($6,1,20),
            $7
        }') | \
        column -t -s $'\t' | sed '2s/[^-]/-/g'  # Format the output as a table
    else
        echo "Details for container $1:"
        container_info=$(docker inspect "$1" 2>/dev/null)  # Get detailed information about the specified container
        if [ $? -eq 0 ]; then
            echo "$container_info" | jq '.[0] | {Id, Name, State, Image, Mounts}'  # Format the output 
        else
            echo "Error: No such container: $1"  # Handle case where the container does not exist
        fi
    fi
}

# Function to display Nginx information
display_nginx() {
    if [ -z "$1" ]; then  # Check if no specific domain is provided
        echo "Nginx Domains and Ports:"
        # Retrieve Nginx domains from the configuration files
        domains=$(grep -R server_name /etc/nginx/sites-enabled/ 2>/dev/null | awk '{print $2}' | sed 's/;//')
        if [ -z "$domains" ]; then
            echo "No Nginx domains found or Nginx is not installed."
        else
            (echo -e "Domain\tPort"; echo "$domains" | \
            while read domain; do
                # Get the port for each domain
                port=$(grep -R "listen " /etc/nginx/sites-enabled/ 2>/dev/null | grep -v "#" | awk '{print $2}' | sed 's/;//' | head -1)
                echo -e "$domain\t$port"  # Print the domain and port
            done) | format_table "Domain Port"  # Format the output as a table
        fi
    else
        echo "Nginx configuration for $1:"
        # Show the Nginx configuration for the specified domain
        grep -R -A 20 "server_name $1" /etc/nginx/sites-enabled/ 2>/dev/null || echo "No configuration found for $1"
    fi
}

# Function to display user information
list_all_users() {
    echo "Users on the system and their last login:"
    echo "Username UID GID Home Directory Last Login"
    echo "------------------------------------------------------------"
    # List users with UID >= 1000 (regular users) and their last login times
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read user; do
        userinfo=$(grep "^$user:" /etc/passwd | awk -F: '{print $1, $3, $4, $6}')  # Get user information
        lastlogin=$(lastlog -u "$user" | tail -n 1 | awk '{print $4, $5, $6, $7, $8}')  # Get last login time
        echo "$userinfo $lastlogin"  # Print user information and last login
    done | column -t  # Format the output as a table
}

# Function to display user details
show_user_details() {
    local username=$1  # Store the username passed as an argument
    echo "Details for user $username:"
    id "$username"  # Display user ID and group information
    echo "Last login: $(lastlog -u "$username" | tail -n 1 | awk '{print $4, $5, $6, $7, $8}')"  # Show last login time
}

# Function to display activities within a specified time range
display_time_range() {
    local start_time="$1"  # Store the start time
    local end_time="$2"  # Store the end time
    echo "Requested time range: $start_time to $end_time"
    # Get the earliest and latest timestamps from the journal
    local earliest=$(journalctl --reverse --output=short-iso | tail -n 1 | awk '{print $1"T"$2}')
    local latest=$(journalctl --output=short-iso | head -n 1 | awk '{print $1"T"$2}')
    echo "Available log range: $earliest to $latest"

    # Adjust the time range if the requested range is outside the available range
    if [[ "$start_time" < "$earliest" ]]; then
        start_time="$earliest"
    fi
    if [[ "$end_time" > "$latest" ]]; then
        end_time="$latest"
    fi

    echo "Adjusted time range: $start_time to $end_time"
    # Retrieve activities for the adjusted time range
    activities=$(journalctl --since "$start_time" --until "$end_time" --output=short-iso --no-pager)
    if [ -z "$activities" ]; then
        echo "No activities found in the specified time range."
    else
        echo "Sample of activities found (first 10 entries):"
        echo "$activities" | head -n 10  # This shows the first 10 entries
        echo "..."
        echo "Total entries: $(echo "$activities" | wc -l)"  # Count total entries
    fi

    # Show journal statistics
    echo "Journal statistics:"
    journalctl --header  # Display journal statistics
}

########################## MONITORING MODE ####################################

# Function to run monitoring in continuous mode
continuous_monitoring() {
    echo "Starting continuous monitoring..."
    while true; do
        echo "---- Monitoring at $(date) ----"
        display_ports  # Display active ports
        display_docker  # Display Docker information
        display_nginx  # Display Nginx information
        list_all_users  # List all users
        echo "--------------------------------"
        sleep 240  # Wait for 240 seconds before the next iteration
    done
}

##################################################################

# Function to create a systemd service for devopsfetch
create_service() {
    SCRIPT_PATH=$(readlink -f "$0")  # Get the absolute path of the script
    # Create the service file for systemd
    cat << EOF | sudo tee /etc/systemd/system/devopsfetch.service > /dev/null
[Unit]
Description=DevOps Fetch Service
After=network.target

[Service]
ExecStart=$SCRIPT_PATH
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd to recognize the new service
    sudo systemctl daemon-reload
    # Enable the service to start on boot
    sudo systemctl enable devopsfetch.service
    # Start the service immediately
    sudo systemctl start devopsfetch.service
    echo "DevOps Fetch service created and started."
}

# Handle command line arguments
case "$1" in
    monitor)
        continuous_monitoring  # Start monitoring mode
        ;;
    -p|--port)
        display_ports "$2"  # Display port information
        ;;
    -d|--docker)
        display_docker "$2"  # Display Docker information
        ;;
    -n|--nginx)
        display_nginx "$2"  # Display Nginx information
        ;;
    -u|--users)
        if [ -z "$2" ]; then
            list_all_users  # List all users if no specific user is provided
        else
            show_user_details "$2"  # Show details for a specific user
        fi
        ;;
    -t|--time)
        if [ "$#" -ne 3 ]; then
            echo "Error: You must provide both start and end times."
            display_help  # Show help if arguments are incorrect
        else
            display_time_range "$2" "$3"  # Display activities in the specified time range
        fi
        ;;
    -h|--help)
        display_help  # Show help information
        ;;
    --create-service)
        create_service  # Create and start the systemd service
        ;;
    *)
        echo "Invalid option: $1"  # Handle invalid options
        display_help  # Show help information
        ;;
esac

# Log the end time of the script
echo "Script ended at $(date)"
