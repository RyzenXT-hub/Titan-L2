#!/bin/bash

# Function to display animated loading
function show_loading {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    echo -ne "\e[1;33mInstalling...\e[0m "
    while ps -p $pid > /dev/null; do
        local temp=${spinstr#?}
        printf "[%c] " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "\e[1;36mDone!\e[0m\n"
}

# Install Docker
echo -e "\e[1;93mInstalling Docker...\e[0m"
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Pull nezha123/titan-edge image
echo -e "\e[1;93mPulling nezha123/titan-edge image...\e[0m"
docker pull nezha123/titan-edge

# Install Docker Compose
echo -e "\e[1;93mInstalling Docker Compose...\e[0m"
curl -fsSL https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Move to root directory
cd /root || exit

# Create fake storage directory and disk image
echo "Creating fake storage for Titan node..."
mkdir -p /root/fake_storage
dd if=/dev/zero of=/root/fake_storage/storage.img bs=1M seek=10000000 count=0
mkfs.ext4 /root/fake_storage/storage.img

# Create Dockerfile for Titan node
cat <<EOF > Dockerfile
# Dockerfile for Titan Node

# Base image
FROM ubuntu:latest

# Install necessary packages
RUN apt-get update && apt-get install -y \
    nano \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV TITAN_METADATAPATH /mnt/fake_storage
ENV TITAN_ASSETSPATHS /mnt/fake_storage

# Install Titan Edge binary
COPY titan-edge /usr/bin/titan-edge
RUN chmod +x /usr/bin/titan-edge

# Copy scripts and configuration files
COPY start_node.sh /usr/local/bin/start_node.sh
RUN chmod +x /usr/local/bin/start_node.sh

# Command to run when the container starts
CMD ["start_node.sh"]
EOF

# Create start_node.sh script
cat <<'EOF' > start_node.sh
#!/bin/bash

# Set environment variables
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib

# Start Titan daemon
/usr/bin/titan-edge daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0

# Bind all nodes with the same hash value
HASH_VALUE="64D57164-87A0-4B01-BE38-9D6DD62555F0"
for ((i=1; i<=5; i++))
do
    /usr/bin/titan-edge bind --hash=$HASH_VALUE https://api-test1.container1.titannet.io/api/v2/device/binding
done

# Additional configurations or commands as needed
EOF

# Make start_node.sh executable
chmod +x start_node.sh

# Create docker-compose.yml
cat <<'EOF' > docker-compose.yml
version: '3'
services:
  titan_node:
    build:
      context: .
    container_name: titan_node
    volumes:
      - node_storage:/mnt/fake_storage
    restart: always

volumes:
  node_storage:
    driver: local
    driver_opts:
      type: none
      device: /root/fake_storage
      o: bind
EOF

# Show confirmation message
echo -e "\e[1;93mConfiguration completed.\e[0m"
echo "Starting Titan node..."

# Build and start the Docker container
/usr/local/bin/docker-compose -f /root/docker-compose.yml up -d

# Wait for node to start
sleep 30

# Show status of Titan node
/usr/local/bin/docker-compose -f /root/docker-compose.yml ps

# Create systemd service to run docker-compose on boot
cat <<EOF > /etc/systemd/system/titan_node.service
[Unit]
Description=Titan Node Docker Setup
After=docker.service network-online.target
Requires=docker.service
Restart=always
RestartSec=15

[Service]
Type=oneshot
ExecStart=/usr/local/bin/docker-compose -f /root/docker-compose.yml up -d
WorkingDirectory=/root
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon
systemctl daemon-reload

# Enable the service to start on boot
systemctl enable titan_node.service

# Start the service
systemctl start titan_node.service

# End of script
echo -e "\e[1;94m###################### Installation completed successfully ######################\e[0m"
