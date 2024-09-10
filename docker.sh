#!/bin/bash

# Memeriksa apakah skrip dijalankan sebagai pengguna root
if [ "$(id -u)" != "0" ]; then
    echo "Skrip ini harus dijalankan dengan hak akses pengguna root."
    echo "Cobalah menggunakan perintah 'sudo -i' untuk masuk sebagai root, lalu jalankan skrip ini lagi."
    exit 1
fi

# Fungsi untuk mendapatkan IP publik
function get_public_ip() {
    PUBLIC_IP=$(curl -s ifconfig.me)
    if [ -z "$PUBLIC_IP" ]; then
        echo "Gagal mendapatkan IP publik. Pastikan mesin Anda memiliki akses internet."
        exit 1
    fi
    echo "IP publik yang terdeteksi: $PUBLIC_IP"
}

# Fungsi untuk menjalankan node pada IP publik
function run_nodes_on_public_ip() {
    get_public_ip

    # Konfigurasi default
    id="D4A7BCA5-D6E4-4788-9690-27C4C0FDEF97"
    start_rpc_port=1234
    storage_gb=50

    # Memeriksa apakah Docker sudah diinstal
    if ! command -v docker &> /dev/null
    then
        echo "Docker tidak terdeteksi, sedang menginstal..."
        apt-get install ca-certificates curl gnupg lsb-release -y
        apt-get install docker.io -y
    else
        echo "Docker sudah terinstal."
    fi

    # Menarik image Docker
    docker pull nezha123/titan-edge:1.7

    # Menjalankan 5 node pada IP publik yang terdeteksi
    echo "Menjalankan 5 node pada IP $PUBLIC_IP"
    for i in {1..5}; do
        current_rpc_port=$((start_rpc_port + i - 1))

        # Menggunakan jalur penyimpanan default
        storage_path="/root/titan$i"

        # Memastikan jalur penyimpanan ada
        mkdir -p "$storage_path"

        # Menjalankan kontainer pada IP publik tertentu
        container_id=$(docker run -d --restart always -v "$storage_path:/root/.titanedge/storage" --name "titan_${PUBLIC_IP}_$i" --net=host --add-host="titan_$i:$PUBLIC_IP" nezha123/titan-edge:1.7)

        echo "Node titan_$i pada IP $PUBLIC_IP telah berjalan dengan ID kontainer $container_id menggunakan port $current_rpc_port dan penyimpanan di $storage_path"

        sleep 30

        # Mengubah file config.toml di host untuk mengatur nilai StorageGB dan port
        docker exec $container_id bash -c "\
            sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = $storage_gb/' /root/.titanedge/config.toml && \
            sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_rpc_port\"/' /root/.titanedge/config.toml && \
            echo 'Penyimpanan untuk node titan_$i di IP $PUBLIC_IP diatur menjadi $storage_gb GB, port RPC diatur menjadi $current_rpc_port'"

        # Restart kontainer agar pengaturan berlaku
        docker restart $container_id

        # Bind node dengan kode identitas
        docker exec $container_id bash -c "\
            titan-edge bind --hash=$id https://api-test1.container1.titannet.io/api/v2/device/binding"
        echo "Node titan_$i di IP $PUBLIC_IP telah di-bind."

    done

    echo "============================== Semua node telah diatur dan dijalankan pada IP publik $PUBLIC_IP ================================"
}

# Menjalankan node pada IP publik yang terdeteksi
run_nodes_on_public_ip
