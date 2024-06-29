#!/bin/bash

# Set PATH and LD_LIBRARY_PATH
export PATH=$PATH:/usr/local/titan
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib

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

echo -e "\e[1;93m--------------------------- Configuration INFO ---------------------------\e[0m"
echo "CPU: " $(nproc --all) "vCPU"
echo -n "RAM: " && free -h | awk '/Mem/ {sub(/Gi/, " GB", $2); print $2}'
echo "Disk Space" $(df -B 1G --total | awk '/total/ {print $2}' | tail -n 1) "GB"
echo -e "\e[1;93m--------------------------------------------------------------------------\e[0m"

echo -e "\e[1;93m--------------------------- BASH SHELL TITAN ---------------------------\e[0m"
# Get hash value from terminal
echo "Enter Your Identity code: "
read hash_value

# Check if hash_value is an empty string (the user just presses Enter), then stop the program
if [ -z "$hash_value" ]; then
    echo "No value has been entered. Stop the program."
    exit 1
fi

read -p "Enter cores CPU (default 1): " cpu_core
cpu_core=${cpu_core:-1}

read -p "Enter RAM (default 2 GB): " memory_size
memory_size=${memory_size:-2}

read -p "Enter StorageGB (default 50 GB): " storage_size
storage_size=${storage_size:-50}

service_content="
[Unit]
Description=Titan Node
After=network.target
StartLimitIntervalSec=0

[Service]
User=root
ExecStart=/usr/local/titan/titan-edge daemon start
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
"

sudo apt-get update
sudo apt-get install -y nano

# Download and install the patch package
echo -e "\e[1;93mDownloading patch package...\e[0m"
wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.19/titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz > /dev/null 2>&1 &
download_pid=$!
show_loading $download_pid

sudo tar -xf titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz -C /usr/local > /dev/null 2>&1 &
install_pid=$!
show_loading $install_pid

rm titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz > /dev/null 2>&1

# Rename the extracted directory correctly
if [ -d "/usr/local/titan-edge_v0.1.19_89e53b6_linux_amd64" ]; then
    echo -e "\e[1;93mMoving installation to the correct location...\e[0m"
    sudo mv /usr/local/titan-edge_v0.1.19_89e53b6_linux_amd64 /usr/local/titan
else
    echo -e "\e[91mError: Directory /usr/local/titan-edge_v0.1.19_89e53b6_linux_amd64 does not exist.\e[0m"
    exit 1
fi

# Copy necessary files
if [ -f "/usr/local/titan/libgoworkerd.so" ]; then
    echo -e "\e[1;93mCopying necessary files...\e[0m"
    sudo cp /usr/local/titan/libgoworkerd.so /usr/lib/libgoworkerd.so
else
    echo -e "\e[91mError: File /usr/local/titan/libgoworkerd.so does not exist.\e[0m"
    exit 1
fi

# Definition of content to add
content="
export PATH=\$PATH:/usr/local/titan
export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/lib
"

# Check if the file ~/.bash_profile does not exist, then create a new one, if it already exists, add it
if [ ! -f ~/.bash_profile ]; then
  echo "$content" > ~/.bash_profile
else
  echo "$content" >> ~/.bash_profile
fi

echo -e "\e[1;93mUpdating environment settings...\e[0m"
# Source the .bash_profile to update the current shell environment
source ~/.bash_profile

# Run titan-edge daemon in the background
(titan-edge daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0 &) &
daemon_pid=$!

# Show loading animation for daemon start
show_loading $daemon_pid

echo "PID of titan-edge daemon: $daemon_pid"

# Wait 15 seconds to ensure that the daemon has started successfully
sleep 15

# Run titan-edge bind in the background
(titan-edge bind --hash="$hash_value" https://api-test1.container1.titannet.io/api/v2/device/binding &) &
bind_pid=$!

# Show loading animation for bind process
show_loading $bind_pid

echo "PID of titan-edge bind: $bind_pid"

# Wait for the binding process to finish
wait $bind_pid

sleep 15

# Proceed with other settings

config_file="/root/.titanedge/config.toml"
if [ -f "$config_file" ]; then
    echo "Configuring settings in $config_file..."
    sed -i "s/#StorageGB = 2/StorageGB = $storage_size/" "$config_file"
    echo "Config StorageGB to: $storage_size GB."
    sed -i "s/#MemoryGB = 1/MemoryGB = $memory_size/" "$config_file"
    echo "Config MemoryGB to: $memory_size GB."
    sed -i "s/#Cores = 1/Cores = $cpu_core/" "$config_file"
    echo "Config Cores CPU to: $cpu_core Core."
else
    echo -e "\e[91mError: Configuration file $config_file does not exist.\e[0m"
fi

echo -e "\e[1;93mCreating systemd service...\e[0m"
echo "$service_content" | sudo tee /etc/systemd/system/titand.service > /dev/null

# Stop processes related to titan-edge
echo -e "\e[1;93mStopping titan-edge processes...\e[0m"
pkill titan-edge

# Update systemd
echo -e "\e[1;93mReloading systemd...\e[0m"
sudo systemctl daemon-reload

# Enable and start titand.service
echo -e "\e[1;93mStarting titand.service...\e[0m"
sudo systemctl enable titand.service
sudo systemctl start titand.service

sleep 8
# Displays information and configuration of titan-edge
echo -e "\e[1;96m"
timeout 2  sudo systemctl status titand.service && titan-edge config show && titan-edge info
echo -e "\e[0m"

echo -e "\e[1;94m###################### Installation completed successfully ######################\e[0m"
