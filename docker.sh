#!/bin/bash

# Function to display colored text
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
    echo -e "${YELLOW}This script requires root access.${NC}"
    echo -e "${YELLOW}Please enter root mode using 'sudo -i', then rerun this script.${NC}"
    exec sudo -i
    exit 1
fi

# Prompt the user to enter the identity code
echo -e "${YELLOW}Please enter your identity code:${NC}"
read -p "> " id

# Prompt the user to confirm if they have more than one IP
while true; do
    echo -e "${YELLOW}Do you have more than one public IP? (yes/no):${NC}"
    read -p "> " answer
    case $answer in
        yes)
            echo -e "${YELLOW}Please enter your public IPs, separated by spaces:${NC}"
            read -p "> " -a public_ips
            break
            ;;
        no)
            # Automatically detect the public IP
            public_ips=($(curl -s ifconfig.me))
            break
            ;;
        *)
            echo -e "${YELLOW}Invalid input. Please answer with 'yes' or 'no'.${NC}"
            ;;
    esac
done

# Storage and port settings
storage_gb=50
start_port=1235
container_count=5

# Check if Docker is installed
if ! command -v docker &> /dev/null
then
    echo -e "${GREEN}Docker not detected, installing...${NC}"
    apt-get update
    apt-get install ca-certificates curl gnupg lsb-release -y
    apt-get install docker.io -y
else
    echo -e "${GREEN}Docker is already installed.${NC}"
fi

# Pull the Docker image
echo -e "${GREEN}Pulling the Docker image nezha123/titan-edge...${NC}"
docker pull nezha123/titan-edge

# Set up nodes for each public IP
current_port=$start_port

for ip in "${public_ips[@]}"; do
    echo -e "${GREEN}Setting up node for IP $ip${NC}"

    for ((i=1; i<=container_count; i++))
    do
        storage_path="/root/titan_storage_${ip}_${i}"

        # Ensure storage path exists
        mkdir -p "$storage_path"

        # Run the container with restart always policy
        container_id=$(docker run -d --restart always -v "$storage_path:/root/.titanedge/storage" --name "titan_${ip}_${i}" --net=host nezha123/titan-edge)

        echo -e "${GREEN}Node titan_${ip}_${i} is running with container ID $container_id${NC}"

        sleep 30

        # Modify the config.toml file to set StorageGB and RPC port
        docker exec $container_id bash -c "\
            sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = $storage_gb/' /root/.titanedge/config.toml && \
            sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_port\"/' /root/.titanedge/config.toml && \
            echo 'Storage for node titan_${ip}_${i} set to $storage_gb GB, Port set to $current_port'"

        # Restart the container for the settings to take effect
        docker restart $container_id

        # Bind the node
        docker exec $container_id bash -c "\
            titan-edge bind --hash=$id https://api-test1.container1.titannet.io/api/v2/device/binding"
        echo -e "${GREEN}Node titan_${ip}_${i} has been bound.${NC}"

        current_port=$((current_port + 1))
    done
done

echo -e "${GREEN}============================== All nodes have been set up and are running ===============================${NC}"
