#!/bin/bash

# Cek Root
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Jalankan dengan sudo!"
  exit
fi

echo "🚀 INSTALLING HAZI BACKEND (SAFE MODE)..."

# 1. Cek Requirement (Tanpa Install Ulang)
if ! command -v node &> /dev/null; then
    echo "❌ Node.js tidak ditemukan! Install manual dulu."
    exit 1
fi

if ! command -v pm2 &> /dev/null; then
    echo "❌ PM2 tidak ditemukan! Install manual dulu."
    exit 1
fi

# 2. Setup Folder Khusus Hazi (Tidak mengganggu project lain)
INSTALL_DIR="/opt/hazi-backend"
LOG_FILE="/var/log/hazi-tunnel.log"

echo "📂 Memindahkan file ke $INSTALL_DIR..."
mkdir -p $INSTALL_DIR
cp -rf * $INSTALL_DIR/

# 3. Install Dependencies Lokal (Hanya di folder hazi)
cd $INSTALL_DIR
echo "📦 Installing Dependencies (Local)..."
if [ ! -f "package.json" ]; then
    npm init -y
    npm install express cors
else
    npm install
fi

# 4. Setup Cloudflared (Cek dulu sebelum install)
echo "☁️ Cek Cloudflared..."
if ! command -v cloudflared &> /dev/null; then
    echo "⬇️ Cloudflared belum ada, download..."
    ARCH=$(dpkg --print-architecture)
    if [ "$ARCH" = "arm64" ]; then
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O /usr/local/bin/cloudflared
    elif [ "$ARCH" = "armhf" ]; then
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm -O /usr/local/bin/cloudflared
    else
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
    fi
    chmod +x /usr/local/bin/cloudflared
else
    echo "✅ Cloudflared sudah terinstall. Skip download."
fi

# 5. PM2 Management (Hanya refresh service Hazi)
# Hapus process hazi lama jika ada (tidak sentuh project port 3001)
pm2 delete hazi-backend 2> /dev/null
pm2 delete hazi-tunnel 2> /dev/null

# 6. Start Backend (Port 3000)
echo "🔥 Starting Hazi Backend (Port 3000)..."
pm2 start server.js --name hazi-backend

# 7. Start Tunnel
# Buat wrapper script
echo "#!/bin/bash
/usr/local/bin/cloudflared tunnel --url http://localhost:3000 > $LOG_FILE 2>&1" > run-tunnel.sh
chmod +x run-tunnel.sh

# Setup log file permission
touch $LOG_FILE
chmod 666 $LOG_FILE

echo "🔥 Starting Hazi Tunnel..."
pm2 start ./run-tunnel.sh --name hazi-tunnel

# 8. Save PM2 List
# Ini akan menggabungkan process lama (3001) + process baru (3000)
echo "💾 Saving PM2 List..."
pm2 save

echo "=========================================="
echo "✅ INSTALASI AMAN SELESAI!"
echo "=========================================="
echo "Project lama Anda di port 3001: TETAP AMAN."
echo "Project Hazi di port 3000: AKTIF."
echo "=========================================="
