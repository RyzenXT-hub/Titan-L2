#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fungsi untuk mengganti ':' jadi '-' agar path Docker valid (IPv6 fix)
sanitize_ip() {
    echo "$1" | sed 's/:/-/g'
}

if [ "$(id -u)" != "0" ]; then
    echo -e "${YELLOW}This script requires root access.${NC}"
    echo -e "${YELLOW}Please enter root mode using 'sudo -i', then rerun this script.${NC}"
    exit 1
fi

echo -e "${YELLOW}Please enter your identity code:${NC}"
read -rp "> " id

storage_gb=50
start_port=1235

# Pilih jumlah node
while true; do
    read -rp "Enter the number of nodes to create (max 5, default 5): " container_count
    container_count=${container_count:-5}
    if [[ "$container_count" -ge 1 && "$container_count" -le 5 ]]; then
        break
    else
        echo -e "${YELLOW}Please enter a valid number between 1 and 5.${NC}"
    fi
done

# Ambil IP publik
public_ip=$(curl -s ifconfig.me)

if [ -z "$public_ip" ]; then
    echo -e "${YELLOW}No public IP detected.${NC}"
    exit 1
fi

# Cek dan install Docker jika belum ada
if ! command -v docker &> /dev/null; then
    echo -e "${GREEN}Docker not detected, installing...${NC}"
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release docker.io
else
    echo -e "${GREEN}Docker is already installed.${NC}"
fi

echo -e "${GREEN}Pulling the Docker image nezha123/titan-edge...${NC}"
docker pull nezha123/titan-edge

current_port=$start_port
safe_ip=$(sanitize_ip "$public_ip")

for ((i=1; i<=container_count; i++)); do
    storage_path="/root/titan_storage_${safe_ip}_${i}"
    container_name="titan_${safe_ip}_${i}"

    echo -e "${GREEN}Setting up node $container_name${NC}"

    # Skip jika container sudah ada
    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo -e "${YELLOW}Container $container_name already exists. Skipping...${NC}"
        continue
    fi

    mkdir -p "$storage_path"

    container_id=$(docker run -d --restart always -v "$storage_path:/root/.titanedge/storage" --name "$container_name" --net=host nezha123/titan-edge)

    echo -e "${GREEN}Node $container_name is running with container ID $container_id${NC}"

    sleep 30

    docker exec "$container_id" bash -c "\
        sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = $storage_gb/' /root/.titanedge/config.toml && \
        sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_port\"/' /root/.titanedge/config.toml"

    docker restart "$container_id"

    echo -e "${GREEN}Binding node $container_name...${NC}"
    if docker exec "$container_id" bash -c "titan-edge bind --hash=$id https://api-test1.container1.titannet.io/api/v2/device/binding"; then
        echo -e "${GREEN}Node $container_name has been successfully bound.${NC}"
    else
        echo -e "${YELLOW}Binding failed for $container_name. Please check manually.${NC}"
    fi

    current_port=$((current_port + 1))
done

echo -e "${GREEN}============================== All nodes have been set up and are running ===============================${NC}"
