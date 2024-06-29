#!/bin/bash

# Download and install the patch
wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.19/titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz
sudo tar -xf titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz -C /usr/local/titan
rm titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz

# Stop processes related to titan-edge
pkill titan-edge

# Update systemd
sudo systemctl daemon-reload

# Restart titand.service
sudo systemctl restart titand.service

# Check the status and show the configuration and info
sleep 8
sudo systemctl status titand.service && titan-edge config show && titan-edge info

echo "Update Succesfully"
