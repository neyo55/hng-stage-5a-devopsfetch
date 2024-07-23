#!/bin/bash

# If running from command line, don't redirect output
if [ -t 1 ]; then
    exec 1>/dev/tty
    exec 2>&1
else
    # Debug logging for service mode
    exec 3>&1 4>&2
    trap 'exec 2>&4 1>&3' 0 1 2 3
    exec 1>/tmp/devopsfetch.log 2>&1
fi

echo "Script started at $(date)"
echo "Running with argument: $1"

# devopsfetch - Server Information Retrieval and Monitoring Tool

# Function to display help
display_help() {
    echo "Usage: devopsfetch [OPTION]... [ARGUMENT]..."
    echo "Retrieve and display server information."
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
    echo "  devopsfetch -p 80              # Show details for port 80"
    echo "  devopsfetch -d                 # List all Docker images and containers"
    echo "  devopsfetch -d mycontainer     # Show details for 'mycontainer'"
    echo "  devopsfetch -n                 # List all Nginx domains"
    echo "  devopsfetch -n example.com     # Show Nginx config for example.com"
    echo "  devopsfetch -u                 # List all users and last login times"
    echo "  devopsfetch -u johndoe         # Show details for user 'johndoe'"
    echo "  devopsfetch -t '2023-01-01 00:00:00' '2023-01-31 23:59:59'  # Show activities in January 2023"
}

# Function to format output as a table
format_table() {
    local header="$1"
    shift
    (echo "$header"; cat) | column -t -s $'\t' | sed '2s/[^|]/-/g'
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
    if [ -z "$1" ]; then
        echo "Docker Images:"
        docker images | format_table "REPOSITORY TAG IMAGE_ID CREATED SIZE"
        echo
        echo "Docker Containers:"
        docker ps -a | format_table "CONTAINER_ID IMAGE COMMAND CREATED STATUS PORTS NAMES"
    else
        echo "Details for container $1:"
        docker inspect $1 | jq '.[0] | {Id, Name, State, Image, Mounts}'
    fi
}

# Function to display Nginx information
display_nginx() {
    if [ -z "$1" ]; then
        echo "Nginx Domains and Ports:"
        (echo -e "Domain\tPort"; grep -R server_name /etc/nginx/sites-enabled/ | awk '{print $2}' | sed 's/;//' | \
        while read domain; do
            port=$(grep -R "listen " /etc/nginx/sites-enabled/ | grep -v "#" | awk '{print $2}' | sed 's/;//' | head -1)
            echo -e "$domain\t$port"
        done) | format_table "Domain Port"
    else
        echo "Nginx configuration for $1:"
        grep -R -A 20 "server_name $1" /etc/nginx/sites-enabled/
    fi
}

# Function to display user information
display_users() {
    if [ -z "$1" ]; then
        echo "Users and Last Login Times:"
        (echo -e "Username\tIP\tDate\tTime"; last -w | awk '!seen[$1]++ {print $1, $3, $4, $5, $6}') | \
        format_table "Username IP Date Time"
    else
        echo "Details for user $1:"
        id $1
        echo "Last login:"
        last $1 | head -1
    fi
}

# Function to display activities within a time range
display_time_range() {
    echo "Activities between $1 and $2:"
    (echo -e "Time\tUser\tCommand"; journalctl --since "$1" --until "$2" | \
    awk '{print $3, $4, $5, $6, $7}' | tail -n 50) | \
    format_table "Time User Command"
}

# Function for continuous monitoring
continuous_monitoring() {
    while true; do
        echo "--- System Status at $(date) ---"
        display_ports
        display_docker
        display_nginx
        display_users
        echo "--------------------------------"
        sleep 300  # Wait for 5 minutes before the next check
    done
}

# Main script logic
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
        display_users "$2"
        ;;
    -t|--time)
        display_time_range "$2" "$3"
        ;;
    -h|--help)
        display_help
        ;;
    *)
        echo "Invalid option. Use -h or --help for usage information."
        exit 1
        ;;
esac












# #!/bin/bash

# # If running from command line, don't redirect output
# if [ -t 1 ]; then
#     exec 1>/dev/tty
#     exec 2>&1
# else
#     # Debug logging for service mode
#     exec 3>&1 4>&2
#     trap 'exec 2>&4 1>&3' 0 1 2 3
#     exec 1>/tmp/devopsfetch.log 2>&1
# fi

# echo "Script started at $(date)"
# echo "Running with argument: $1"

# # devopsfetch - Server Information Retrieval and Monitoring Tool

# # Function to display help
# display_help() {
#     echo "Usage: devopsfetch [OPTION]... [ARGUMENT]..."
#     echo "Retrieve and display server information."
#     echo
#     echo "Options:"
#     echo "  monitor               Run in continuous monitoring mode"
#     echo "  -p, --port [PORT]     Display active ports or info about a specific port"
#     echo "  -d, --docker [CONTAINER] List Docker images/containers or info about a specific container"
#     echo "  -n, --nginx [DOMAIN]  Display Nginx domains or config for a specific domain"
#     echo "  -u, --users [USER]    List users and last login times or info about a specific user"
#     echo "  -t, --time START END  Display activities within a specified time range"
#     echo "  -h, --help            Display this help message"
#     echo
#     echo "Examples:"
#     echo "  devopsfetch monitor            # Run in continuous monitoring mode"
#     echo "  devopsfetch -p                 # List all active ports"
#     echo "  devopsfetch -p 80              # Show details for port 80"
#     echo "  devopsfetch -d                 # List all Docker images and containers"
#     echo "  devopsfetch -d mycontainer     # Show details for 'mycontainer'"
#     echo "  devopsfetch -n                 # List all Nginx domains"
#     echo "  devopsfetch -n example.com     # Show Nginx config for example.com"
#     echo "  devopsfetch -u                 # List all users and last login times"
#     echo "  devopsfetch -u johndoe         # Show details for user 'johndoe'"
#     echo "  devopsfetch -t '2023-01-01 00:00:00' '2023-01-31 23:59:59'  # Show activities in January 2023"
# }

# # Function to format output as a table
# format_table() {
#     column -t -s $'\t'
# }

# # Function to display port information
# display_ports() {
#     if [ -z "$1" ]; then
#         echo "Active Ports and Services:"
#         ss -tuln | awk 'NR>1 {print $5}' | awk -F: '{print $NF}' | sort -n | uniq | \
#         while read port; do
#             service=$(lsof -i :$port | awk 'NR==2 {print $1}')
#             echo -e "$port\t$service"
#         done | format_table
#     else
#         echo "Details for port $1:"
#         lsof -i :$1
#     fi
# }

# # Function to display Docker information
# display_docker() {
#     if [ -z "$1" ]; then
#         echo "Docker Images:"
#         docker images | format_table
#         echo
#         echo "Docker Containers:"
#         docker ps -a | format_table
#     else
#         echo "Details for container $1:"
#         docker inspect $1 | jq '.[0] | {Id, Name, State, Image, Mounts}'
#     fi
# }

# # Function to display Nginx information
# display_nginx() {
#     if [ -z "$1" ]; then
#         echo "Nginx Domains and Ports:"
#         grep -R server_name /etc/nginx/sites-enabled/ | awk '{print $2}' | sed 's/;//' | \
#         while read domain; do
#             port=$(grep -R "listen " /etc/nginx/sites-enabled/ | grep -v "#" | awk '{print $2}' | sed 's/;//' | head -1)
#             echo -e "$domain\t$port"
#         done | format_table
#     else
#         echo "Nginx configuration for $1:"
#         grep -R -A 20 "server_name $1" /etc/nginx/sites-enabled/
#     fi
# }

# # Function to display user information
# display_users() {
#     if [ -z "$1" ]; then
#         echo "Users and Last Login Times:"
#         last -w | awk '!seen[$1]++ {print $1, $3, $4, $5, $6}' | format_table
#     else
#         echo "Details for user $1:"
#         id $1
#         echo "Last login:"
#         last $1 | head -1
#     fi
# }

# # Function to display activities within a time range
# display_time_range() {
#     echo "Activities between $1 and $2:"
#     journalctl --since "$1" --until "$2" | tail -n 50
# }

# # Function for continuous monitoring
# continuous_monitoring() {
#     while true; do
#         echo "--- System Status at $(date) ---"
#         display_ports
#         display_docker
#         display_nginx
#         display_users
#         echo "--------------------------------"
#         sleep 300  # Wait for 5 minutes before the next check
#     done
# }

# # Main script logic
# case "$1" in
#     monitor)
#         continuous_monitoring
#         ;;
#     -p|--port)
#         display_ports "$2"
#         ;;
#     -d|--docker)
#         display_docker "$2"
#         ;;
#     -n|--nginx)
#         display_nginx "$2"
#         ;;
#     -u|--users)
#         display_users "$2"
#         ;;
#     -t|--time)
#         display_time_range "$2" "$3"
#         ;;
#     -h|--help)
#         display_help
#         ;;
#     *)
#         echo "Invalid option. Use -h or --help for usage information."
#         exit 1
#         ;;
# esac


























# #!/bin/bash

# # If running from command line, don't redirect output
# if [ -t 1 ]; then
#     exec 1>/dev/tty
#     exec 2>&1
# else
#     # Debug logging for service mode
#     exec 3>&1 4>&2
#     trap 'exec 2>&4 1>&3' 0 1 2 3
#     exec 1>/tmp/devopsfetch.log 2>&1
# fi

# echo "Script started at $(date)"
# echo "Running with argument: $1"

# # ... (rest of the script remains the same)

# # Debug logging
# exec 3>&1 4>&2
# trap 'exec 2>&4 1>&3' 0 1 2 3
# exec 1>/tmp/devopsfetch.log 2>&1

# echo "Script started at $(date)"

# # devopsfetch - Server Information Retrieval and Monitoring Tool

# # Function to display help
# display_help() {
#     echo "Usage: devopsfetch [OPTION]... [ARGUMENT]..."
#     echo "Retrieve and display server information."
#     echo
#     echo "Options:"
#     echo "  monitor               Run in continuous monitoring mode"
#     echo "  -p, --port [PORT]     Display active ports or info about a specific port"
#     echo "  -d, --docker [CONTAINER] List Docker images/containers or info about a specific container"
#     echo "  -n, --nginx [DOMAIN]  Display Nginx domains or config for a specific domain"
#     echo "  -u, --users [USER]    List users and last login times or info about a specific user"
#     echo "  -t, --time START END  Display activities within a specified time range"
#     echo "  -h, --help            Display this help message"
#     echo
#     echo "Examples:"
#     echo "  devopsfetch monitor            # Run in continuous monitoring mode"
#     echo "  devopsfetch -p                 # List all active ports"
#     echo "  devopsfetch -p 80              # Show details for port 80"
#     echo "  devopsfetch -d                 # List all Docker images and containers"
#     echo "  devopsfetch -d mycontainer     # Show details for 'mycontainer'"
#     echo "  devopsfetch -n                 # List all Nginx domains"
#     echo "  devopsfetch -n example.com     # Show Nginx config for example.com"
#     echo "  devopsfetch -u                 # List all users and last login times"
#     echo "  devopsfetch -u johndoe         # Show details for user 'johndoe'"
#     echo "  devopsfetch -t '2023-01-01 00:00:00' '2023-01-31 23:59:59'  # Show activities in January 2023"
# }

# # Function to format output as a table
# format_table() {
#     column -t -s $'\t'
# }

# # Function to display port information
# display_ports() {
#     if [ -z "$1" ]; then
#         echo "Active Ports and Services:"
#         ss -tuln | awk 'NR>1 {print $5}' | awk -F: '{print $NF}' | sort -n | uniq | \
#         while read port; do
#             service=$(lsof -i :$port | awk 'NR==2 {print $1}')
#             echo -e "$port\t$service"
#         done | format_table
#     else
#         echo "Details for port $1:"
#         lsof -i :$1
#     fi
# }

# # Function to display Docker information
# display_docker() {
#     if [ -z "$1" ]; then
#         echo "Docker Images:"
#         docker images | format_table
#         echo
#         echo "Docker Containers:"
#         docker ps -a | format_table
#     else
#         echo "Details for container $1:"
#         docker inspect $1 | jq '.[0] | {Id, Name, State, Image, Mounts}'
#     fi
# }

# # Function to display Nginx information
# display_nginx() {
#     if [ -z "$1" ]; then
#         echo "Nginx Domains and Ports:"
#         grep -R server_name /etc/nginx/sites-enabled/ | awk '{print $2}' | sed 's/;//' | \
#         while read domain; do
#             port=$(grep -R "listen " /etc/nginx/sites-enabled/ | grep -v "#" | awk '{print $2}' | sed 's/;//' | head -1)
#             echo -e "$domain\t$port"
#         done | format_table
#     else
#         echo "Nginx configuration for $1:"
#         grep -R -A 20 "server_name $1" /etc/nginx/sites-enabled/
#     fi
# }

# # Function to display user information
# display_users() {
#     if [ -z "$1" ]; then
#         echo "Users and Last Login Times:"
#         last -w | awk '!seen[$1]++ {print $1, $3, $4, $5, $6}' | format_table
#     else
#         echo "Details for user $1:"
#         id $1
#         echo "Last login:"
#         last $1 | head -1
#     fi
# }

# # Function to display activities within a time range
# display_time_range() {
#     echo "Activities between $1 and $2:"
#     journalctl --since "$1" --until "$2" | tail -n 50
# }

# # Function for continuous monitoring
# continuous_monitoring() {
#     while true; do
#         echo "--- System Status at $(date) ---"
#         display_ports
#         display_docker
#         display_nginx
#         display_users
#         echo "--------------------------------"
#         sleep 300  # Wait for 5 minutes before the next check
#     done
# }

# # Main script logic
# case "$1" in
#     monitor)
#         continuous_monitoring
#         ;;
#     -p|--port)
#         display_ports "$2"
#         ;;
#     -d|--docker)
#         display_docker "$2"
#         ;;
#     -n|--nginx)
#         display_nginx "$2"
#         ;;
#     -u|--users)
#         display_users "$2"
#         ;;
#     -t|--time)
#         display_time_range "$2" "$3"
#         ;;
#     -h|--help)
#         display_help
#         ;;
#     *)
#         echo "Invalid option. Use -h or --help for usage information."
#         exit 1
#         ;;
# esac






