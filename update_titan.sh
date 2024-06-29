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
wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.19/titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz & show_loading
print_success "Done."

echo -n "Extracting the update package..."
sudo tar -xf titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz -C /usr/local & show_loading
rm titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz
print_success "Done."

# Move the new installation to the correct location
if [ -d "/usr/local/titan-edge_v0.1.19_89e53b6_linux_amd64" ]; then
    echo -n "Moving the new installation to the correct location..."
    sudo mv /usr/local/titan-edge_v0.1.19_89e53b6_linux_amd64 /usr/local/titan & show_loading
    print_success "Done."
else
    echo "Error: Directory /usr/local/titan-edge_v0.1.19_89e53b6_linux_amd64 does not exist."
    exit 1
fi

# Copy necessary files
if [ -f "/usr/local/titan/libgoworkerd.so" ]; then
    echo -n "Copying necessary files..."
    sudo cp /usr/local/titan/libgoworkerd.so /usr/lib/libgoworkerd.so & show_loading
    print_success "Done."
else
    echo "Error: File /usr/local/titan/libgoworkerd.so does not exist."
    exit 1
fi

# Add titan to PATH and LD_LIBRARY_PATH in .bash_profile
echo -n "Adding titan to PATH and LD_LIBRARY_PATH in .bash_profile..."
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
print_success "Done."

# Source the .bash_profile to update the current shell environment
source ~/.bash_profile

# Run titan-edge daemon in the background
echo -n "Running the titan-edge daemon..."
(titan-edge daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0 &) &
daemon_pid=$!
show_loading
print_success "Daemon PID: $daemon_pid"

# Wait 15 seconds to ensure that the daemon has started successfully
sleep 15

# Run titan-edge bind in the background
echo -n "Running titan-edge bind..."
(titan-edge bind --hash="$hash_value" https://api-test1.container1.titannet.io/api/v2/device/binding &) &
bind_pid=$!
show_loading
print_success "Bind PID: $bind_pid"

# Wait for the binding process to finish
wait $bind_pid

# Update systemd
echo -n "Updating systemd..."
sudo systemctl daemon-reload & show_loading
print_success "Done."

# Restart titand.service
echo -n "Restarting the titand.service..."
sudo systemctl restart titand.service & show_loading
print_success "Done."

# Check the status and show the configuration and info
echo -n "Checking the service status..."
sleep 8
sudo systemctl status titand.service && titan-edge config show && titan-edge info

print_success "########################## UPDATE COMPLETED ##########################"

