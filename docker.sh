#!/bin/bash

# Memeriksa apakah skrip dijalankan sebagai pengguna root
if [ "$(id -u)" != "0" ]; then
    echo "Skrip ini harus dijalankan dengan hak akses pengguna root."
    echo "Cobalah menggunakan perintah 'sudo -i' untuk masuk sebagai root, lalu jalankan skrip ini lagi."
    exit 1
fi

function install_node() {
    # Membaca kode identitas
    read -p "Masukkan kode identitas Anda: " id

    # Meminta pengguna untuk memasukkan jumlah kontainer yang ingin dibuat
    read -p "Masukkan jumlah node yang ingin dibuat, maksimal 5 node per IP: " container_count

    # Meminta pengguna memasukkan port RPC awal
    read -p "Masukkan port RPC awal yang ingin diatur (port akan berurutan untuk 5 node, disarankan memasukkan 30000): " start_rpc_port

    # Meminta pengguna memasukkan ukuran penyimpanan yang ingin dialokasikan
    read -p "Masukkan ukuran penyimpanan yang ingin dialokasikan untuk setiap node (GB), batas maksimum per node adalah 2T. Pengaruh perubahan di website membutuhkan waktu 20 menit: " storage_gb

    # Meminta pengguna memasukkan jalur penyimpanan (opsional)
    read -p "Masukkan jalur penyimpanan data node di host (tekan enter untuk menggunakan jalur default titan_storage_$i): " custom_storage_path

    apt update

    # Memeriksa apakah Docker sudah diinstal
    if ! command -v docker &> /dev/null
    then
        echo "Docker tidak terdeteksi, sedang menginstal..."
        apt-get install ca-certificates curl gnupg lsb-release -y
        
        # Menginstal Docker versi terbaru
        apt-get install docker.io -y
    else
        echo "Docker sudah terinstal."
    fi

    # Menarik image Docker
    docker pull nezha123/titan-edge:1.7

    # Membuat jumlah kontainer sesuai yang ditentukan oleh pengguna
    for ((i=1; i<=container_count; i++))
    do
        current_rpc_port=$((start_rpc_port + i - 1))

        # Memeriksa apakah pengguna memasukkan jalur penyimpanan kustom
        if [ -z "$custom_storage_path" ]; then
            # Pengguna tidak memasukkan, menggunakan jalur default
            storage_path="$PWD/titan_storage_$i"
        else
            # Pengguna memasukkan jalur kustom, menggunakan jalur tersebut
            storage_path="$custom_storage_path"
        fi

        # Memastikan jalur penyimpanan ada
        mkdir -p "$storage_path"

        # Memeriksa apakah kontainer dengan nama yang sama sudah ada
        if [ "$(docker ps -a -q -f name=titan$i)" ]; then
            echo "Kontainer titan$i sudah ada. Menghapus kontainer yang ada terlebih dahulu."
            docker stop "titan$i"
            docker rm "titan$i"
        fi

        # Menjalankan kontainer, dengan kebijakan restart selalu
        container_id=$(docker run -d --restart always -v "$storage_path:/root/.titanedge/storage" --name "titan$i" --net=host  nezha123/titan-edge:1.7)

        echo "Node titan$i telah berjalan dengan ID kontainer $container_id"

        sleep 30

        # Mengubah file config.toml di host untuk mengatur nilai StorageGB dan port
        docker exec $container_id bash -c "\
            sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = $storage_gb/' /root/.titanedge/config.toml && \
            sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_rpc_port\"/' /root/.titanedge/config.toml && \
            echo 'Penyimpanan untuk node titan'$i' diatur menjadi $storage_gb GB, port RPC diatur menjadi $current_rpc_port'"

        # Restart kontainer agar pengaturan berlaku
        docker restart $container_id

        # Masuk ke kontainer dan menjalankan perintah bind
        docker exec $container_id bash -c "\
            titan-edge bind --hash=$id https://api-test1.container1.titannet.io/api/v2/device/binding"
        echo "Node titan$i telah di-bind."

    done

    echo "==============================Semua node telah diatur dan dijalankan==================================="

}

# Fungsi untuk menghapus node
function uninstall_node() {
    echo "Apakah Anda yakin ingin menghapus program node Titan? Ini akan menghapus semua data terkait. [Y/N]"
    read -r -p "Konfirmasi: " response

    case "$response" in
        [yY][eE][sS]|[yY]) 
            echo "Memulai penghapusan program node..."
            for i in {1..5}; do
                docker stop "titan$i" && docker rm "titan$i"
            done
            for i in {1..5}; do 
                rmName="titan_storage_$i"
                rm -rf "$rmName"
            done
            echo "Program node telah dihapus."
            ;;
        *)
            echo "Membatalkan operasi penghapusan."
            ;;
    esac
}

# Menu utama
function main_menu() {
    while true; do
        clear
        echo "Skrip dan tutorial ini ditulis oleh pengguna Twitter @y95277777, open source gratis, jangan percaya jika ada yang berbayar."
        echo "================================================================"
        echo "Grup Telegram komunitas node: https://t.me/niuwuriji"
        echo "Channel Telegram komunitas node: https://t.me/niuwuriji"
        echo "Server Discord komunitas node: https://discord.gg/GbMV5EcNWF"
        echo "Untuk keluar dari skrip, tekan ctrl + c."
        echo "Pilih operasi yang ingin dijalankan:"
        echo "1. Instal node"
        echo "2. Hapus node"
        read -p "Masukkan pilihan (1-2): " OPTION

        case $OPTION in
        1) install_node ;;
        2) uninstall_node ;;
        *) echo "Pilihan tidak valid." ;;
        esac
        echo "Tekan tombol apa saja untuk kembali ke menu utama..."
        read -n 1
    done
    
}

# Menampilkan menu utama
main_menu
