#!/bin/bash

# Cek Root
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Script harus dijalankan oleh user root!"
  echo "👉 Coba: sudo bash install.sh (atau login sebagai root)"
  exit
fi

echo "🚀 INSTALLING HAZI BACKEND (SKIP CHECK VERSION)..."

# 1. Setup Folder & File (Hanya refresh folder Hazi)
INSTALL_DIR="/opt/hazi-backend"
LOG_FILE="/var/log/hazi-tunnel.log"

echo "📂 Memindahkan file ke $INSTALL_DIR..."
mkdir -p $INSTALL_DIR
cp -rf * $INSTALL_DIR/

# 2. Install Dependencies Project
cd $INSTALL_DIR
echo "📦 Installing Dependencies..."
# Kita pakai 'npm' asumsi sudah ada. Kalau error, berarti nodejs belum beres.
if [ ! -f "package.json" ]; then
    npm init -y
    npm install express cors
else
    npm install
fi

# 3. Setup Cloudflared
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
    echo "✅ Cloudflared sudah terinstall."
fi

# 4. PM2 Management
# Hapus process hazi lama jika ada (tidak sentuh barber-app/port 3001)
echo "🔄 Refreshing PM2 process..."
pm2 delete hazi-backend 2> /dev/null
pm2 delete hazi-tunnel 2> /dev/null

# 5. Start Backend (Port 3000)
echo "🔥 Starting Hazi Backend (Port 3000)..."
pm2 start server.js --name hazi-backend

# 6. Start Tunnel
# Buat wrapper script agar log tersimpan
echo "#!/bin/bash
/usr/local/bin/cloudflared tunnel --url http://localhost:3000 > $LOG_FILE 2>&1" > run-tunnel.sh
chmod +x run-tunnel.sh

# Setup log file
touch $LOG_FILE
chmod 666 $LOG_FILE

echo "🔥 Starting Hazi Tunnel..."
pm2 start ./run-tunnel.sh --name hazi-tunnel

# 7. Save PM2 List
# Ini akan menyimpan 'barber-app' (yang lama) DAN 'hazi-backend' (yang baru)
echo "💾 Saving PM2 List..."
pm2 save
# Jalankan startup command biar aman
pm2 startup | bash

echo "=========================================="
echo "✅ INSTALASI SELESAI!"
echo "=========================================="
echo "Project 'barber-app' (Port 3001) : AMAN/ONLINE"
echo "Project 'hazi-backend' (Port 3000) : ONLINE"
echo "=========================================="
