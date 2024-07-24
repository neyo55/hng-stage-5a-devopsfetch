#!/bin/bash

# Configure journald to retain logs persistently
sudo mkdir -p /var/log/journal
sudo chown root:systemd-journal /var/log/journal
sudo chmod 2755 /var/log/journal
sudo systemctl restart systemd-journald

# Always log to file and terminal
exec > >(tee -a /tmp/devopsfetch.log) 2>&1

echo "Script started at $(date)"
echo "Running with argument: $1"

# devopsfetch - Server Information Retrieval and Monitoring Tool

# Function to display help
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
    echo "  devopsfetch -u Amaka           # Show details for user 'Amaka'"
    echo "  devopsfetch -t '2024-01-01 00:00:00' '2024-01-31 00:00:00'  # Show activities in January 2024"
}

# Function to format output as a table
format_table() {
    local header="$1"
    shift
    (echo "$header"; cat) | column -t -s $'\t' | sed '2s/[^-]/-/g'
}

# Function to display port information
display_ports() {
    if [ -z "$1" ]; then
        echo "Active Ports and Services:"
        (echo -e "Port\tService"; ss -tuln | awk 'NR>1 {print $5}' | awk -F: '{print $NF}' | sort -n | uniq | \
        while read port; do
            service=$(lsof -i :$port | awk 'NR==2 {print $1}')
            echo -e "$port\t$service"
        done) | format_table "Port Service"
    else
        echo "Details for port $1:"
        lsof -i :$1
    fi
}

# Function to display Docker information
display_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed or not in PATH"
        return 1
    fi

    if ! docker info &> /dev/null; then
        echo "Error: Docker daemon is not running"
        return 1
    fi

    if [ -z "$1" ]; then
        echo "Docker Images (showing latest 15):"
        (docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}" | head -n 16 | \
        awk 'NR==1 {print} NR>1 {printf "%-40s\t%-15s\t%-12s\t%-20s\t%s\n", substr($1,1,40), substr($2,1,15), substr($3,1,12), substr($4,1,20), $5}') | \
        column -t -s $'\t' | sed '2s/[^-]/-/g'

        echo
        echo "Docker Containers (showing latest 10):"
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
        column -t -s $'\t' | sed '2s/[^-]/-/g'
    else
        echo "Details for container $1:"
        container_info=$(docker inspect "$1" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "$container_info" | jq '.[0] | {Id, Name, State, Image, Mounts}'
        else
            echo "Error: No such container: $1"
        fi
    fi
}

# Function to display Nginx information
display_nginx() {
    if [ -z "$1" ]; then
        echo "Nginx Domains and Ports:"
        domains=$(grep -R server_name /etc/nginx/sites-enabled/ 2>/dev/null | awk '{print $2}' | sed 's/;//')
        if [ -z "$domains" ]; then
            echo "No Nginx domains found or Nginx is not installed."
        else
            (echo -e "Domain\tPort"; echo "$domains" | \
            while read domain; do
                port=$(grep -R "listen " /etc/nginx/sites-enabled/ 2>/dev/null | grep -v "#" | awk '{print $2}' | sed 's/;//' | head -1)
                echo -e "$domain\t$port"
            done) | format_table "Domain Port"
        fi
    else
        echo "Nginx configuration for $1:"
        grep -R -A 20 "server_name $1" /etc/nginx/sites-enabled/ 2>/dev/null || echo "No configuration found for $1"
    fi
}


# Function to display user information
list_all_users() {
    echo "Users on the system and their last login:"
    echo "Username UID GID Home Directory Last Login"
    echo "------------------------------------------------------------"
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read user; do
        userinfo=$(grep "^$user:" /etc/passwd | awk -F: '{print $1, $3, $4, $6}')
        lastlogin=$(lastlog -u "$user" | tail -n 1 | awk '{print $4, $5, $6, $7, $8}')
        echo "$userinfo $lastlogin"
    done | column -t
}

# Function to display user details
show_user_details() {
    local username=$1
    echo "Details for user $username:"
    id "$username"
    echo "Last login: $(lastlog -u "$username" | tail -n 1 | awk '{print $4, $5, $6, $7, $8}')"
}

# function to display activities within a time range
display_time_range() {
    local start_time="$1"
    local end_time="$2"

    echo "Requested time range: $start_time to $end_time"

    # Get the earliest and latest timestamps from the journal
    local earliest=$(journalctl --reverse --output=short-iso | tail -n 1 | awk '{print $1"T"$2}')
    local latest=$(journalctl --output=short-iso | head -n 1 | awk '{print $1"T"$2}')

    echo "Available log range: $earliest to $latest"

    # Use the available range if the requested range is out of bounds
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
        echo "$activities" | head -n 10
        echo "..."
        echo "Total entries: $(echo "$activities" | wc -l)"
    fi

    # Show journal statistics
    echo "Journal statistics:"
    journalctl --header
}

########################## MONITORING MODE ####################################
# Function to run monitoring in continuous mode
continuous_monitoring() {
    echo "Starting continuous monitoring..."
    while true; do
        echo "---- Monitoring at $(date) ----"
        display_ports
        display_docker
        display_nginx
        list_all_users
        echo "--------------------------------"
        sleep 240
    done
}
##################################################################

# Function to create service
create_service() {
    SCRIPT_PATH=$(readlink -f "$0")
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

    sudo systemctl daemon-reload
    sudo systemctl enable devopsfetch.service
    sudo systemctl start devopsfetch.service
    echo "DevOps Fetch service created and started."
}

# Handle command line arguments
case "$1" in
    monitor)
        continuous_monitoring
        ;;
    -p|--port)
        display_ports "$2"
        ;;
    -d|--docker)
        display_docker "$2"
        ;;
    -n|--nginx)
        display_nginx "$2"
        ;;
    -u|--users)
        if [ -z "$2" ]; then
            list_all_users
        else
            show_user_details "$2"
        fi
        ;;
    -t|--time)
        if [ "$#" -ne 3 ]; then
            echo "Error: You must provide both start and end times."
            display_help
        else
            display_time_range "$2" "$3"
        fi
        ;;
    -h|--help)
        display_help
        ;;
    --create-service)
        create_service
        ;;
    *)
        echo "Invalid option: $1"
        display_help
        ;;
esac

echo "Script ended at $(date)"