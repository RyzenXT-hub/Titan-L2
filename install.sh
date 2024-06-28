#!/bin/bash
# Set PATH and LD_LIBRARY_PATH
export PATH=$PATH:/usr/local/titan
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib

echo "--------------------------- Configuration INFO ---------------------------"
echo "CPU: " $(nproc --all) "vCPU"
echo -n "RAM: " && free -h | awk '/Mem/ {sub(/Gi/, " GB", $2); print $2}'
echo "Disk Space" $(df -B 1G --total | awk '/total/ {print $2}' | tail -n 1) "GB"
echo "--------------------------------------------------------------------------"

echo "--------------------------- BASH SHELL TITAN ---------------------------"
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

wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.19/titan-edge_v0.1.19_linux_amd64.tar.gz

sudo tar -xf titan-edge_v0.1.19_linux_amd64.tar.gz -C /usr/local

sudo mv /usr/local/titan-edge_v0.1.19_linux_amd64 /usr/local/titan
sudo cp /usr/local/titan/libgoworkerd.so /usr/lib/libgoworkerd.so

rm titan-edge_v0.1.19_linux_amd64.tar.gz

# Definition of content to add
content="
export PATH=\$PATH:/usr/local/titan
export LD_LIBRARY_PATH=\$LD_LIZBRARY_PATH:/usr/lib
"

# Check if the file ~/.bash_profile does not exist, then create a new one, if it already exists, add it
if [ ! -f ~/.bash_profile ]; then
  echo "$content" > ~/.bash_profile
else
  echo "$content" >> ~/.bash_profile
fi

echo "Export PATH ~/.bash_profile"

# Run titan-edge daemon in the background
(titan-edge daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0 &) &
daemon_pid=$!

echo "PID of titan-edge daemon: $daemon_pid"

# Wait 10 seconds to ensure that the daemon has started successfully
sleep 15

# Run titan-edge bind in the background
(titan-edge bind --hash="$hash_value" https://api-test1.container1.titannet.io/api/v2/device/binding &) &
bind_pid=$!

echo "PID of titan-edge bind: $bind_pid"

# Wait for the binding process to finish
wait $bind_pid

sleep 15

# Proceed with other settings

config_file="/root/.titanedge/config.toml"
if [ -f "$config_file" ]; then
    sed -i "s/#StorageGB = 2/StorageGB = $storage_size/" "$config_file"
    echo "Config StorageGB to: $storage_size GB."
    sed -i "s/#MemoryGB = 1/MemoryGB = $memory_size/" "$config_file"
    echo "Config MemoryGB to: $memory_size GB."
    sed -i "s/#Cores = 1/Cores = $cpu_core/" "$config_file"
    echo "Config Cores CPU to: $cpu_core Core."
else
    echo "Error: Configuration file $config_file does not exist."
fi

echo "$service_content" | sudo tee /etc/systemd/system/titand.service > /dev/null

# Stop processes related to titan-edge
pkill titan-edge

# Update systemd
sudo systemctl daemon-reload

# Enable and start titand.service
sudo systemctl enable titand.service
sudo systemctl start titand.service

sleep 8
# Displays information and configuration of titan-edge
sudo systemctl status titand.service && titan-edge config show && titan-edge info
