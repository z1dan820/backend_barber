#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
  echo "❌ Jalankan dengan sudo!"
  exit
fi

echo "🚀 INSTALLING HAZI BACKEND (CLEAN INSTALL)..."

INSTALL_DIR="/opt/hazi-backend"
LOG_FILE="/var/log/hazi-tunnel.log"

# 1. Setup Folder
echo "📂 Memindahkan file ke $INSTALL_DIR..."
mkdir -p $INSTALL_DIR
cp -rf * $INSTALL_DIR/

# 2. Install Dependencies
cd $INSTALL_DIR
echo "📦 Installing Dependencies..."
if [ ! -f "package.json" ]; then
    npm init -y
    npm install express cors
else
    npm install
fi

# 3. Setup Cloudflared (Skip jika sudah ada)
if ! command -v cloudflared &> /dev/null; then
    echo "☁️ Downloading cloudflared..."
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
fi

# 4. START PROCESS (PM2)
# Hapus yang lama biar fresh
pm2 delete hazi-backend 2> /dev/null
pm2 delete hazi-tunnel 2> /dev/null

echo "🔥 Starting Backend..."
pm2 start server.js --name hazi-backend

echo "🔥 Starting Tunnel..."
# Buat wrapper script log
echo "#!/bin/bash
/usr/local/bin/cloudflared tunnel --url http://localhost:3000 > $LOG_FILE 2>&1" > run-tunnel.sh
chmod +x run-tunnel.sh
touch $LOG_FILE && chmod 666 $LOG_FILE

pm2 start ./run-tunnel.sh --name hazi-tunnel

# 5. Save Startup
echo "💾 Saving PM2 List..."
pm2 save

echo "✅ INSTALASI SELESAI!"
