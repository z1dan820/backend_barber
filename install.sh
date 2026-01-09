#!/bin/bash

# Pastikan run sebagai root
if [ "$EUID" -ne 0 ]; then 
  echo "Jalankan dengan sudo!"
  exit
fi

echo "🚀 INSTALLING HAZI BACKEND FROM GITHUB..."

# 1. Tentukan Direktori Install Permanen
INSTALL_DIR="/opt/hazi-backend"

# 2. Update & Install Node.js + Tools
apt-get update
apt-get install -y curl wget git

if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
fi

# 3. Pindahkan File ke /opt/
echo "📂 Setup folder di $INSTALL_DIR..."
mkdir -p $INSTALL_DIR
# Copy semua file dari folder saat ini (repo git) ke folder install
cp -r * $INSTALL_DIR/

# 4. Install Dependencies
cd $INSTALL_DIR
echo "📦 Installing NPM Modules..."
npm install

# 5. Install Cloudflared (Auto Detect Arch)
echo "☁️ Setup Cloudflared..."
if ! command -v cloudflared &> /dev/null; then
    ARCH=$(dpkg --print-architecture)
    if [ "$ARCH" = "arm64" ]; then
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O /usr/local/bin/cloudflared
    elif [ "$ARCH" = "armhf" ]; then
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm -O /usr/local/bin/cloudflared
    else
        echo "⚠️ Arsitektur $ARCH mungkin butuh install manual. Mencoba amd64..."
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
    fi
    chmod +x /usr/local/bin/cloudflared
fi

# 6. Service: Backend
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

# 7. Service: Tunnel
echo "⚙️ Creating Service: hazi-tunnel"
cat <<EOF > /etc/systemd/system/hazi-tunnel.service
[Unit]
Description=Cloudflare Tunnel for Hazi
After=network.target hazi-backend.service

[Service]
Type=simple
User=root
ExecStart=/bin/sh -c '/usr/local/bin/cloudflared tunnel --url http://localhost:3000 > /var/log/hazi-tunnel.log 2>&1'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 8. Start Semua
systemctl daemon-reload
systemctl enable hazi-backend
systemctl enable hazi-tunnel
systemctl restart hazi-backend
systemctl restart hazi-tunnel

echo "✅ DONE! Cek domain dengan perintah:"
echo "cat /var/log/hazi-tunnel.log | grep trycloudflare.com"

