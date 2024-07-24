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

# Move to home directory
cd ~ || exit

# Create directories for each node
echo "Creating directories for Titan nodes..."
for i in {1..5}
do
    mkdir -p ~/.titanedge/node$i
done

# Create Docker Compose configuration file
cat <<EOF > docker-compose.yml
version: '3'
services:
EOF

# Create Docker Compose configuration for each node
for i in {1..5}
do
    cat <<EOF >> docker-compose.yml
  node$i:
    image: nezha123/titan-edge
    container_name: titan_node$i
    volumes:
      - ~/.titanedge/node$i:/root/.titanedge
    command: bind --hash=A1C483BE-3F43-4A6C-9DAA-9FD4E176C596 https://api-test$i.container$i.titannet.io/api/v2/device/binding
    restart: always
EOF
done

# Show confirmation message
echo -e "\e[1;93mConfiguration completed.\e[0m"
echo "Starting Titan nodes..."

# Build and start the Docker containers
/usr/local/bin/docker-compose -f ~/docker-compose.yml up -d

# End of script
echo -e "\e[1;94m###################### Installation completed successfully ######################\e[0m"
