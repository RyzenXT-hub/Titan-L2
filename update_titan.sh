#!/bin/bash

# Function to show loading message
show_loading() {
    pid=$!
    spin='-\|/'
    i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r%s" "${spin:$i:1}"
        sleep .1
    done
    printf "\r"
}

echo "Memulai proses pembaruan..."

# Stop the existing titan-edge service
echo -n "Menghentikan layanan titan-edge..."
sudo systemctl stop titand.service & show_loading
echo "Selesai."

# Remove existing titan-edge files
echo -n "Menghapus file titan-edge yang lama..."
sudo rm -rf /usr/local/titan & show_loading
echo "Selesai."

# Download and install the patch
echo -n "Mengunduh paket pembaruan..."
wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.19/titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz & show_loading
echo "Selesai."

echo -n "Mengekstrak paket pembaruan..."
sudo tar -xf titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz -C /usr/local & show_loading
rm titan-l2edge_v0.1.19_patch_linux_amd64.tar.gz
echo "Selesai."

# Move the new installation to the correct location
if [ -d "/usr/local/titan-edge_v0.1.19_89e53b6_linux_amd64" ]; then
    echo -n "Memindahkan instalasi baru ke lokasi yang benar..."
    sudo mv /usr/local/titan-edge_v0.1.19_89e53b6_linux_amd64 /usr/local/titan & show_loading
    echo "Selesai."
else
    echo "Error: Directory /usr/local/titan-edge_v0.1.19_89e53b6_linux_amd64 does not exist."
    exit 1
fi

# Copy necessary files
if [ -f "/usr/local/titan/libgoworkerd.so" ]; then
    echo -n "Menyalin file yang diperlukan..."
    sudo cp /usr/local/titan/libgoworkerd.so /usr/lib/libgoworkerd.so & show_loading
    echo "Selesai."
else
    echo "Error: File /usr/local/titan/libgoworkerd.so does not exist."
    exit 1
fi

# Add titan to PATH and LD_LIBRARY_PATH in .bash_profile
echo -n "Menambahkan titan ke PATH dan LD_LIBRARY_PATH di .bash_profile..."
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
echo "Selesai."

# Source the .bash_profile to update the current shell environment
source ~/.bash_profile

# Run titan-edge daemon in the background
echo -n "Menjalankan daemon titan-edge..."
(titan-edge daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0 &) &
daemon_pid=$!
show_loading
echo "PID daemon titan-edge: $daemon_pid"

# Wait 15 seconds to ensure that the daemon has started successfully
sleep 15

# Run titan-edge bind in the background
echo -n "Menjalankan titan-edge bind..."
(titan-edge bind --hash="$hash_value" https://api-test1.container1.titannet.io/api/v2/device/binding &) &
bind_pid=$!
show_loading
echo "PID titan-edge bind: $bind_pid"

# Wait for the binding process to finish
wait $bind_pid

# Update systemd
echo -n "Memperbarui systemd..."
sudo systemctl daemon-reload & show_loading
echo "Selesai."

# Restart titand.service
echo -n "Memulai ulang layanan titand.service..."
sudo systemctl restart titand.service & show_loading
echo "Selesai."

# Check the status and show the configuration and info
echo -n "Memeriksa status layanan..."
sleep 8
sudo systemctl status titand.service && titan-edge config show && titan-edge info
echo "########################## UPDATE COMPLETED ##########################"
