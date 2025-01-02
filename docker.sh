#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ "$(id -u)" != "0" ]; then
    echo -e "${YELLOW}This script requires root access.${NC}"
    echo -e "${YELLOW}Please enter root mode using 'sudo -i', then rerun this script.${NC}"
    exec sudo -i
    exit 1
fi

echo -e "${YELLOW}Please enter your identity code:${NC}"
read -p "> " id

storage_gb=50
start_port=1235

# Interaksi untuk memilih jumlah node
while true; do
    read -p "Enter the number of nodes to create (max 5, default 5): " container_count
    container_count=${container_count:-5}
    if [[ "$container_count" -ge 1 && "$container_count" -le 5 ]]; then
        break
    else
        echo -e "${YELLOW}Please enter a valid number between 1 and 5.${NC}"
    fi
done

public_ips=$(curl -s ifconfig.me)

if [ -z "$public_ips" ]; then
    echo -e "${YELLOW}No public IP detected.${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null
then
    echo -e "${GREEN}Docker not detected, installing...${NC}"
    apt-get update
    apt-get install ca-certificates curl gnupg lsb-release -y
    apt-get install docker.io -y
else
    echo -e "${GREEN}Docker is already installed.${NC}"
fi

echo -e "${GREEN}Pulling the Docker image nezha123/titan-edge...${NC}"
docker pull nezha123/titan-edge

current_port=$start_port

for ip in $public_ips; do
    echo -e "${GREEN}Setting up nodes for IP $ip${NC}"

    for ((i=1; i<=container_count; i++))
    do
        storage_path="/root/titan_storage_${ip}_${i}"

        mkdir -p "$storage_path"

        container_id=$(docker run -d --restart always -v "$storage_path:/root/.titanedge/storage" --name "titan_${ip}_${i}" --net=host nezha123/titan-edge)

        echo -e "${GREEN}Node titan_${ip}_${i} is running with container ID $container_id${NC}"

        sleep 30

        docker exec $container_id bash -c "\
            sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = $storage_gb/' /root/.titanedge/config.toml && \
            sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_port\"/' /root/.titanedge/config.toml && \
            echo 'Storage for node titan_${ip}_${i} set to $storage_gb GB, Port set to $current_port'"

        docker restart $container_id

        docker exec $container_id bash -c "\
            titan-edge bind --hash=$id https://api-test1.container1.titannet.io/api/v2/device/binding"
        echo -e "${GREEN}Node titan_${ip}_${i} has been bound.${NC}"

        current_port=$((current_port + 1))
    done
done

echo -e "${GREEN}============================== All nodes have been set up and are running ===============================${NC}"
