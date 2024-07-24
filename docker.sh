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

# Update package index and install necessary packages
echo "Updating package index..."
apt-get update

echo "Installing prerequisites..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add Docker repository for Ubuntu Focal (20.04)
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"

# Install Docker Engine
echo "Installing Docker Engine..."
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Verify Docker installation
echo "Verifying Docker installation..."
docker --version

# Pull Titan Edge Docker image
echo "Pulling Titan Edge Docker image..."
docker pull nezha123/titan-edge

# Move to root directory
cd /root

# Create fake storage directories and disk images for 5 nodes
for i in {1..5}
do
    echo "Creating fake storage for node$i..."
    mkdir -p /path/to/fake_node$i
    dd if=/dev/zero of=/path/to/fake_node$i/storage.img bs=1M seek=50000 count=0
    mkfs.ext4 /path/to/fake_node$i/storage.img
done

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

# Copy scripts and configuration files
COPY start_node.sh /usr/local/bin/start_node.sh
RUN chmod +x /usr/local/bin/start_node.sh

# Command to run when the container starts
CMD ["start_node.sh"]
EOF

# Create start_node.sh script
cat <<'EOF' > start_node.sh
#!/bin/bash

# Download and install Titan
wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.19/titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz
tar -zxvf titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz
mv titan-l2edge_v0.1.19_patch_linux_amd64 /usr/local/titan

# Set environment variables
export PATH=$PATH:/usr/local/titan
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib

# Start Titan daemon
titan-edge daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0

# Bind all nodes with the same hash value
HASH_VALUE="75AA5F6F-3E03-48DC-A93D-2DC85A71A85B"
for ((i=1; i<=5; i++))
do
    titan-edge bind --hash=$HASH_VALUE https://api-test1.container1.titannet.io/api/v2/device/binding
done

# Additional configurations or commands as needed
EOF

# Make start_node.sh executable
chmod +x start_node.sh

# Create systemd service to run setup_titan_nodes.sh on boot
cat <<EOF > /etc/systemd/system/titan_nodes.service
[Unit]
Description=Titan Nodes Docker Setup
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/bin/bash /root/docker.sh
WorkingDirectory=/root
StandardOutput=journal

# Restart on failure or reboot after 15 seconds
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon
systemctl daemon-reload

# Enable the service to start on boot
systemctl enable titan_nodes.service

# Start the service
systemctl start titan_nodes.service

# End of script
echo -e "\e[1;94m###################### Installation completed successfully ######################\e[0m"
