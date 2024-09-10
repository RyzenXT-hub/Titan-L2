#!/bin/bash

# Memeriksa apakah skrip dijalankan sebagai pengguna root
if [ "$(id -u)" != "0" ]; then
    echo "Skrip ini harus dijalankan dengan hak akses pengguna root."
    echo "Cobalah menggunakan perintah 'sudo -i' untuk masuk sebagai root, lalu jalankan skrip ini lagi."
    exit 1
fi

echo "Mencari kontainer dengan nama 'titan'..."

# Mendapatkan daftar kontainer dengan nama yang sesuai
containers=$(docker ps -a --filter "name=titan" --format "{{.ID}}")

echo "Kontainer ditemukan: $containers"

if [ -z "$containers" ]; then
    echo "Tidak ada kontainer yang ditemukan untuk dihapus."
    exit 1
fi

# Menghentikan dan menghapus semua kontainer
for container_id in $containers
do
    echo "Menghapus kontainer dengan ID $container_id..."
    docker stop $container_id
    docker rm $container_id
done

# Menghapus direktori penyimpanan
echo "Menghapus direktori penyimpanan..."
rm -rf /root/titan_storage_*

echo "Semua node telah dihapus."
