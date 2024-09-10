#!/bin/bash

# Memeriksa apakah skrip dijalankan sebagai root
if [ "$(id -u)" != "0" ]; then
    echo "Skrip ini harus dijalankan dengan hak akses pengguna root."
    echo "Cobalah menggunakan perintah 'sudo -i' untuk masuk sebagai root, lalu jalankan skrip ini lagi."
    exit 1
fi

# Fungsi untuk mendeteksi semua IP yang terpasang pada instance
function detect_ips() {
    echo "Mendeteksi IP yang terpasang pada instance..."
    # Mendapatkan semua alamat IP kecuali 127.0.0.1
    IPs=($(ip -o -4 addr show | awk '{print $4}' | cut -d/ -f1 | grep -v '127.0.0.1'))

    # Memeriksa apakah ada IP yang terdeteksi
    if [ ${#IPs[@]} -eq 0 ]; then
        echo "Tidak ada IP yang terdeteksi."
        exit 1
    else
        echo "IP yang terdeteksi: ${IPs[@]}"
    fi
}

# Fungsi untuk menjalankan node pada setiap IP
function run_nodes_on_ip() {
    detect_ips

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

    # Membuat node pada setiap IP
    for ip in "${IPs[@]}"; do
        echo "Menjalankan 5 node pada IP $ip"
        for i in {1..5}; do
            current_rpc_port=$((start_rpc_port + i - 1))
            
            # Menggunakan jalur penyimpanan berbeda untuk setiap node
            storage_path="/root/titan${i}"

            # Memastikan jalur penyimpanan ada
            mkdir -p "$storage_path"

            # Menjalankan kontainer pada IP tertentu
            container_id=$(docker run -d --restart always -v "$storage_path:/root/.titanedge/storage" --name "titan_${ip}_$i" --net=host nezha123/titan-edge:1.7)

            echo "Node titan_$i pada IP $ip telah berjalan dengan ID kontainer $container_id menggunakan port $current_rpc_port dan penyimpanan di $storage_path"

            sleep 30

            # Mengubah file config.toml di host untuk mengatur nilai StorageGB dan port
            docker exec $container_id bash -c "\
                sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = $storage_gb/' /root/.titanedge/config.toml && \
                sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_rpc_port\"/' /root/.titanedge/config.toml && \
                echo 'Penyimpanan untuk node titan_$i di IP $ip diatur menjadi $storage_gb GB, port RPC diatur menjadi $current_rpc_port'"

            # Restart kontainer agar pengaturan berlaku
            docker restart $container_id

            # Bind node dengan kode identitas
            docker exec $container_id bash -c "\
                titan-edge bind --hash=$id https://api-test1.container1.titannet.io/api/v2/device/binding"
            echo "Node titan_$i di IP $ip telah di-bind dan berjalan di port $current_rpc_port dengan penyimpanan di $storage_path."
        done
    done

    echo "============================== Semua node telah diatur dan dijalankan pada IP yang terdeteksi ================================"
}

# Menjalankan node pada semua IP yang terdeteksi
run_nodes_on_ip
