#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script requires root access."
    echo "Switch to root mode using 'sudo -i', then run the script again."
    exec sudo -i
    exit 1
fi

# Prompt the user to enter the identity ID
read -p "Enter your identity code: " id

# Storage and port settings
storage_gb=50
start_rpc_port=1235
container_count=5

# Retrieve the list of public IPs
public_ips=$(curl -s ifconfig.me)

if [ -z "$public_ips" ]; then
    echo "No public IP detected."
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null
then
    echo "Docker not detected, installing..."
    apt-get update
    apt-get install ca-certificates curl gnupg lsb-release -y
    apt-get install docker.io -y
else
    echo "Docker is already installed."
fi

# Pull the Docker image
docker pull nezha123/titan-edge

# Set up nodes for each public IP
current_port=$start_rpc_port

for ip in $public_ips; do
    echo "Setting up node for IP $ip"

    for ((i=1; i<=container_count; i++))
    do
        storage_path="/root/titan_storage_${ip}_${i}"

        # Ensure the storage path exists
        mkdir -p "$storage_path"

        # Run the container with the 'always' restart policy
        container_id=$(docker run -d --restart always -v "$storage_path:/root/.titanedge/storage" --name "titan_${ip}_${i}" --net=host nezha123/titan-edge)

        echo "Node titan_${ip}_${i} is running with container ID $container_id"

        sleep 30

        # Modify the config.toml file on the host to set the StorageGB and port values
        docker exec $container_id bash -c "\
            sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = $storage_gb/' /root/.titanedge/config.toml && \
            sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_port\"/' /root/.titanedge/config.toml && \
            echo 'Storage for node titan_${ip}_${i} set to $storage_gb GB, RPC port set to $current_port'"

        # Restart the container for the settings to take effect
        docker restart $container_id

        # Enter the container and run the bind command
        docker exec $container_id bash -c "\
            titan-edge bind --hash=$id https://api-test1.container1.titannet.io/api/v2/device/binding"
        echo "Node titan_${ip}_${i} has been bound."

        current_port=$((current_port + 1))
    done
done

echo "============================== Installation successfully completed ================================"
