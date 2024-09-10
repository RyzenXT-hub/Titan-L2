#!/bin/bash

# Memeriksa apakah skrip dijalankan sebagai pengguna root
if [ "$(id -u)" != "0" ]; then
    echo "Skrip ini memerlukan hak akses root."
    echo "Masuk ke mode root menggunakan 'sudo -i', lalu jalankan skrip lagi."
    exec sudo -i
    exit 1
fi

# ID identitas
id="3EDB66D2-FC98-4D51-85CC-F9042F36721C"

# Penyimpanan dan port
storage_gb=50
start_rpc_port=1234
container_count=5

# Mendapatkan daftar IP publik
public_ips=$(curl -s ifconfig.me)

if [ -z "$public_ips" ]; then
    echo "Tidak ada IP publik yang terdeteksi."
    exit 1
fi

# Memeriksa apakah Docker sudah diinstal
if ! command -v docker &> /dev/null
then
    echo "Docker tidak terdeteksi, sedang menginstal..."
    apt-get update
    apt-get install ca-certificates curl gnupg lsb-release -y
    apt-get install docker.io -y
else
    echo "Docker sudah terinstal."
fi

# Menarik image Docker
docker pull nezha123/titan-edge

# Mengatur node pada setiap IP publik
current_port=$start_rpc_port

for ip in $public_ips; do
    echo "Menyiapkan node untuk IP $ip"

    for ((i=1; i<=container_count; i++))
    do
        storage_path="/root/titan_storage_${ip}_${i}"

        # Memastikan jalur penyimpanan ada
        mkdir -p "$storage_path"

        # Menjalankan kontainer dengan kebijakan restart selalu
        container_id=$(docker run -d --restart always -v "$storage_path:/root/.titanedge/storage" --name "titan_${ip}_${i}" --net=host nezha123/titan-edge)

        echo "Node titan_${ip}_${i} telah berjalan dengan ID kontainer $container_id"

        sleep 30

        # Mengubah file config.toml di host untuk mengatur nilai StorageGB dan port
        docker exec $container_id bash -c "\
            sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = $storage_gb/' /root/.titanedge/config.toml && \
            sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_port\"/' /root/.titanedge/config.toml && \
            echo 'Penyimpanan untuk node titan_${ip}_${i} diatur menjadi $storage_gb GB, port RPC diatur menjadi $current_port'"

        # Restart kontainer agar pengaturan berlaku
        docker restart $container_id

        # Masuk ke kontainer dan menjalankan perintah bind
        docker exec $container_id bash -c "\
            titan-edge bind --hash=$id https://api-test1.container1.titannet.io/api/v2/device/binding"
        echo "Node titan_${ip}_${i} telah di-bind."

        current_port=$((current_port + 1))
    done
done

echo "==============================Semua node telah diatur dan dijalankan==================================="
