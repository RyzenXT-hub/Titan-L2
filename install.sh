#!/bin/bash

# Function to show loading animation in yellow
show_loading() {
    pid=$!
    spin='-\|/'
    i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r\033[0;33m%s\033[0m" "${spin:$i:1}"
        sleep .1
    done
    printf "\r"
}

# Function to print success message in light blue
print_success() {
    printf "\033[1;34m%s\033[0m\n" "$1"
}

echo -e "\033[1;33m--------------------------- Configuration INFO ---------------------------\033[0m"
echo -e "\033[1;33mCPU: $(nproc --all) vCPU\033[0m"
echo -en "\033[1;33mRAM: " && free -h | awk '/Mem/ {sub(/Gi/, " GB", $2); print $2}'
echo -e "\033[1;33mDisk Space $(df -B 1G --total | awk '/total/ {print $2}' | tail -n 1) GB\033[0m"
echo -e "\033[1;33m--------------------------------------------------------------------------\033[0m"

echo -e "\033[1;33m--------------------------- BASH SHELL TITAN ---------------------------\033[0m"
# Get hash value from terminal
echo -e "\033[1;33mEnter Your Identity code: \033[0m"
read hash_value

# Check if hash_value is an empty string (the user just presses Enter), then stop the program
if [ -z "$hash_value" ]; then
    echo -e "\033[1;31mNo value has been entered. Stop the program.\033[0m"
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

echo -e "\033[1;33mUpdating system packages...\033[0m"
sudo apt-get update & show_loading
print_success "System packages updated."

echo -e "\033[1;33mInstalling nano...\033[0m"
sudo apt-get install -y nano & show_loading
print_success "Nano installed."

# Download and install the patch package
echo -e "\033[1;33mDownloading and installing the patch package...\033[0m"
wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.19/titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz & show_loading
print_success "Patch package downloaded and installed."

sudo tar -xf titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz -C /usr/local & show_loading
rm titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz

# Rename the extracted directory correctly
if [ -d "/usr/local/titan-edge_v0.1.19_89e53b6_linux_amd64" ]; then
    echo -e "\033[1;33mMoving the new installation to the correct location...\033[0m"
    sudo mv /usr/local/titan-edge_v0.1.19_89e53b6_linux_amd64 /usr/local/titan & show_loading
    print_success "Installation moved to /usr/local/titan."
else
    echo -e "\033[1;31mError: Directory /usr/local/titan-edge_v0.1.19_89e53b6_linux_amd64 does not exist.\033[0m"
    exit 1
fi

# Copy necessary files
if [ -f "/usr/local/titan/libgoworkerd.so" ]; then
    echo -e "\033[1;33mCopying necessary files...\033[0m"
    sudo cp /usr/local/titan/libgoworkerd.so /usr/lib/libgoworkerd.so & show_loading
    print_success "Files copied successfully."
else
    echo -e "\033[1;31mError: File /usr/local/titan/libgoworkerd.so does not exist.\033[0m"
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

echo -e "\033[1;33mUpdating environment settings...\033[0m"
source ~/.bash_profile & show_loading
print_success "Environment settings updated."

# Run titan-edge daemon in the background
echo -e "\033[1;33mStarting titan-edge daemon...\033[0m"
(titan-edge daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0 &) &
daemon_pid=$!
show_loading
print_success "Daemon started. PID: $daemon_pid"

# Wait 15 seconds to ensure that the daemon has started successfully
sleep 15

# Run titan-edge bind in the background
echo -e "\033[1;33mRunning titan-edge bind...\033[0m"
(titan-edge bind --hash="$hash_value" https://api-test1.container1.titannet.io/api/v2/device/binding &) &
bind_pid=$!
show_loading
print_success "Bind process started. PID: $bind_pid"

# Wait for the binding process to finish
wait $bind_pid

sleep 15

# Proceed with other settings

config_file="/root/.titanedge/config.toml"
if [ -f "$config_file" ]; then
    echo -e "\033[1;33mConfiguring titan-edge settings...\033[0m"
    sed -i "s/#StorageGB = 2/StorageGB = $storage_size/" "$config_file"
    sed -i "s/#MemoryGB = 1/MemoryGB = $memory_size/" "$config_file"
    sed -i "s/#Cores = 1/Cores = $cpu_core/" "$config_file"
    print_success "Configuration completed."
else
    echo -e "\033[1;31mError: Configuration file $config_file does not exist.\033[0m"
fi

echo -e "\033[1;33mCreating systemd service...\033[0m"
echo "$service_content" | sudo tee /etc/systemd/system/titand.service > /dev/null & show_loading
print_success "Systemd service created."

# Stop processes related to titan-edge
echo -e "\033[1;33mStopping titan-edge processes...\033[0m"
pkill titan-edge & show_loading
print_success "Processes stopped."

# Update systemd
echo -e "\033[1;33mReloading systemd...\033[0m"
sudo systemctl daemon-reload & show_loading
print_success "Systemd reloaded."

# Enable and start titand.service
echo -e "\033[1;33mEnabling and starting titan service...\033[0m"
sudo systemctl enable titand.service & show_loading
sudo systemctl start titand.service & show_loading
print_success "Service enabled and started."

sleep 8
# Displays information and configuration of titan-edge
echo -e "\033[1;34m---------------------------------------------------\033[0m"
echo -e "\033[1;34mTitan-edge status:\033[0m"
sudo systemctl status titand.service
echo -e "\033[1;34m---------------------------------------------------\033[0m"
echo -e "\033[1;34mCurrent titan-edge configuration:\033[0m"
titan-edge config show
echo -e "\033[1;34m---------------------------------------------------\033[0m"
echo -e "\033[1;34mTitan-edge information:\033[0m"
titan-edge info
echo -e "\033[1;34m---------------------------------------------------\033[0m"

echo -e "\033[1;34mInstallation successfully completed.\033[0m"
