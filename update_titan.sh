#!/bin/bash

# Stop the existing titan-edge service
sudo systemctl stop titand.service

# Remove existing titan-edge files
sudo rm -rf /usr/local/titan

# Download and install the patch
wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.19/titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz
sudo tar -xf titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz -C /usr/local
rm titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz

# Move the new installation to the correct location
sudo mv /usr/local/titan-l2edge_v0.1.19_patch_linux_amd64 /usr/local/titan

# Copy necessary files
sudo cp /usr/local/titan/libgoworkerd.so /usr/lib/libgoworkerd.so

# Add titan to PATH and LD_LIBRARY_PATH in .bash_profile
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

# Source the .bash_profile to update the current shell environment
source ~/.bash_profile

# Run titan-edge daemon in the background
(titan-edge daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0 &) &
daemon_pid=$!

echo "PID of titan-edge daemon: $daemon_pid"

# Wait 15 seconds to ensure that the daemon has started successfully
sleep 15

# Run titan-edge bind in the background
(titan-edge bind --hash="$hash_value" https://api-test1.container1.titannet.io/api/v2/device/binding &) &
bind_pid=$!

echo "PID of titan-edge bind: $bind_pid"

# Wait for the binding process to finish
wait $bind_pid

# Update systemd
sudo systemctl daemon-reload

# Restart titand.service
sudo systemctl restart titand.service

# Check the status and show the configuration and info
sleep 8
sudo systemctl status titand.service && titan-edge config show && titan-edge info

echo "Pembaruan selesai."
