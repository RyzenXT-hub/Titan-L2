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

# Update systemd
sudo systemctl daemon-reload

# Restart titand.service
sudo systemctl restart titand.service

# Check the status and show the configuration and info
sleep 8
sudo systemctl status titand.service && titan-edge config show && titan-edge info

echo "Update Succesfully"
