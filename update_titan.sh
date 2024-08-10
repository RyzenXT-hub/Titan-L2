#!/bin/bash

# Function to show loading message with yellow color
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

echo "Starting the update process..."

# Stop the existing titan-edge service
echo -n "Stopping the titan-edge service..."
sudo systemctl stop titand.service & show_loading
print_success "Done."

# Remove existing titan-edge files
echo -n "Removing old titan-edge files..."
sudo rm -rf /usr/local/titan & show_loading
print_success "Done."

# Download and install the patch
echo -n "Downloading the update package..."
wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.20/titan-edge_v0.1.20_246b9dd_linux-amd64.tar.gz & show_loading
print_success "Done."

echo -n "Extracting the update package..."
sudo tar -xf titan-edge_v0.1.20_246b9dd_linux-amd64.tar.gz -C /usr/local & show_loading
rm titan-edge_v0.1.20_246b9dd_linux-amd64.tar.gz
print_success "Done."

# Move the new installation to the correct location
if [ -d "/usr/local/titan-edge_v0.1.20_246b9dd_linux_amd64" ]; then
    echo -n "Moving installation to the correct location..."
    sudo mv /usr/local/titan-edge_v0.1.20_246b9dd_linux_amd64 /usr/local/titan & show_loading
    print_success "Done."
else
    echo -e "\e[91mError: Directory /usr/local/titan-edge_v0.1.20_246b9dd_linux_amd64 does not exist.\e[0m"
    exit 1
fi

# Copy necessary files
if [ -f "/usr/local/titan/libgoworkerd.so" ]; then
    echo -n "Copying necessary files..."
    sudo cp /usr/local/titan/libgoworkerd.so /usr/lib/libgoworkerd.so & show_loading
    print_success "Done."
else
    echo -e "\e[91mError: File /usr/local/titan/libgoworkerd.so does not exist.\e[0m"
    exit 1
fi

echo -n "Reloading systemd..."
sudo systemctl daemon-reload & show_loading
print_success "Done."

echo -n "Restarting the titan-edge service..."
sudo systemctl start titand.service & show_loading
print_success "Done."

# Check the status of the titan-edge service
echo -n "Checking the titan-edge service status..."
sudo systemctl status titand.service & show_loading
