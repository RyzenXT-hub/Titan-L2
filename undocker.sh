#!/bin/bash

# Memeriksa apakah skrip dijalankan sebagai root
if [ "$(id -u)" != "0" ]; then
    echo "Skrip ini harus dijalankan dengan hak akses pengguna root."
    echo "Cobalah menggunakan perintah 'sudo -i' untuk masuk sebagai root, lalu jalankan skrip ini lagi."
    exit 1
fi

# Fungsi untuk menghapus node
function uninstall_nodes() {
    # Meminta pengguna memasukkan IP yang ingin dihapus node-nya
    read -p "Masukkan IP tempat node-node diinstal (misalnya 10.202.0.3): " ip

    echo "Menghapus semua node di IP $ip..."

    # Menghentikan dan menghapus semua kontainer terkait
    for i in {1..5}; do
        container_name="titan_${ip}_$i"
        echo "Menghapus kontainer $container_name..."
        docker stop "$container_name" && docker rm "$container_name"
    done

    # Menghapus jalur penyimpanan yang digunakan
    for i in {1..5}; do
        storage_path="/root/titan$i"
        if [ -d "$storage_path" ]; then
            echo "Menghapus jalur penyimpanan $storage_path..."
            rm -rf "$storage_path"
        fi
    done

    echo "Semua node dan jalur penyimpanan terkait telah dihapus."
}

# Menjalankan fungsi uninstall_nodes
uninstall_nodes
