#!/bin/bash

# Pastikan script dijalankan dengan sudo
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Jalankan dengan sudo!"
  exit
fi

echo "🚀 INSTALLING HAZI BACKEND (GITHUB VERSION)..."

# 1. Tentukan Direktori Install
INSTALL_DIR="/opt/hazi-backend"
LOG_FILE="/var/log/hazi-tunnel.log"

# 2. Update & Install Tools Dasar
echo "📦 Update system..."
apt-get update
apt-get install -y curl wget git

# 3. Install Node.js (jika belum ada)
if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
else
    echo "✅ Node.js sudah terinstall."
fi

# 4. Setup Folder & Copy File
echo "📂 Setup folder di $INSTALL_DIR..."
mkdir -p $INSTALL_DIR

# Copy semua file dari folder saat ini (repo git) ke folder install
# -r = rekursif, -f = force overwrite
cp -rf * $INSTALL_DIR/

# 5. Install Dependencies (Express, Cors)
cd $INSTALL_DIR
echo "📦 Installing NPM Modules..."
# Otomatis install tanpa perlu package.json manual (npm install express cors)
if [ ! -f "package.json" ]; then
    npm init -y
    npm install express cors
else
    npm install
fi

# 6. Install Cloudflared (Auto Detect Architecture)
echo "☁️ Setup Cloudflared..."
if ! command -v cloudflared &> /dev/null; then
    ARCH=$(dpkg --print-architecture)
    if [ "$ARCH" = "arm64" ]; then
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O /usr/local/bin/cloudflared
    elif [ "$ARCH" = "armhf" ]; then
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm -O /usr/local/bin/cloudflared
    else
        echo "⚠️ Arsitektur $ARCH. Mencoba versi amd64..."
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
    fi
    chmod +x /usr/local/bin/cloudflared
fi

# 7. Buat Service Backend (Node.js)
echo "⚙️ Creating Service: hazi-backend"
cat <<EOF > /etc/systemd/system/hazi-backend.service
[Unit]
Description=Hazi Studio Backend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/node server.js
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 8. Buat Service Tunnel (Cloudflared)
# PENTING: Output disimpan ke $LOG_FILE agar bisa dibaca server.js
echo "⚙️ Creating Service: hazi-tunnel"
# Buat file log kosong dulu agar aman
touch $LOG_FILE
chmod 666 $LOG_FILE

cat <<EOF > /etc/systemd/system/hazi-tunnel.service
[Unit]
Description=Cloudflare Tunnel for Hazi
After=network.target hazi-backend.service

[Service]
Type=simple
User=root
# Syntax ini memaksa output stdout & stderr masuk ke file log
ExecStart=/bin/sh -c '/usr/local/bin/cloudflared tunnel --url http://localhost:3000 > $LOG_FILE 2>&1'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 9. Aktifkan Service
echo "🔄 Reloading & Restarting Services..."
systemctl daemon-reload

systemctl enable hazi-backend
systemctl enable hazi-tunnel

systemctl restart hazi-backend
systemctl restart hazi-tunnel

echo "=========================================="
echo "✅ INSTALASI SUKSES!"
echo "=========================================="
echo "Backend Folder : $INSTALL_DIR"
echo "Log File       : $LOG_FILE"
echo ""
echo "👉 Silahkan buka browser HP (Wifi Lokal):"
echo "   http://[IP-STB-KAMU]:3000/admin"
echo ""
echo "   URL Cloudflare akan muncul di sana otomatis."
echo "=========================================="
