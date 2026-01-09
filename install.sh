#!/bin/bash

# Cek Root
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Jalankan dengan sudo!"
  exit
fi

echo "🚀 INSTALLING HAZI BACKEND (PM2 VERSION)..."

# 1. Var & Folder
INSTALL_DIR="/opt/hazi-backend"
LOG_FILE="/var/log/hazi-tunnel.log"
apt-get update
apt-get install -y curl wget git

# 2. Install Node.js
if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
fi

# 3. Install PM2 (Global)
if ! command -v pm2 &> /dev/null; then
    echo "📦 Installing PM2..."
    npm install -g pm2
else
    echo "✅ PM2 sudah terinstall."
fi

# 4. Setup Folder & File
echo "📂 Memindahkan file ke $INSTALL_DIR..."
mkdir -p $INSTALL_DIR
cp -rf * $INSTALL_DIR/

# 5. Install Dependencies Project
cd $INSTALL_DIR
if [ ! -f "package.json" ]; then
    npm init -y
    npm install express cors
else
    npm install
fi

# 6. Install Cloudflared
echo "☁️ Setup Cloudflared..."
if ! command -v cloudflared &> /dev/null; then
    ARCH=$(dpkg --print-architecture)
    if [ "$ARCH" = "arm64" ]; then
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O /usr/local/bin/cloudflared
    elif [ "$ARCH" = "armhf" ]; then
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm -O /usr/local/bin/cloudflared
    else
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
    fi
    chmod +x /usr/local/bin/cloudflared
fi

# 7. STOP & DELETE Process Lama (Jika ada) agar bersih
pm2 delete hazi-backend 2> /dev/null
pm2 delete hazi-tunnel 2> /dev/null

# 8. START BACKEND (Node.js)
echo "🔥 Starting Backend..."
pm2 start server.js --name hazi-backend

# 9. START TUNNEL (Cloudflared)
# Kita buat script wrapper kecil agar output log bisa diarahkan ke file
# Ini PENTING supaya server.js bisa membaca URL-nya
echo "#!/bin/bash
/usr/local/bin/cloudflared tunnel --url http://localhost:3000 > $LOG_FILE 2>&1" > run-tunnel.sh
chmod +x run-tunnel.sh

# Pastikan file log ada dan permission aman
touch $LOG_FILE
chmod 666 $LOG_FILE

echo "🔥 Starting Tunnel..."
pm2 start ./run-tunnel.sh --name hazi-tunnel

# 10. SETUP AUTOSTART (PM2 Startup)
echo "💾 Saving PM2 List & Startup..."
pm2 save
# Command ini mendeteksi sistem init (systemd) dan membuat autostart untuk user root
pm2 startup systemd -u root --hp /root

echo "=========================================="
echo "✅ INSTALASI PM2 SELESAI!"
echo "=========================================="
echo "👉 Cek status: pm2 status"
echo "👉 Cek log tunnel: pm2 logs hazi-tunnel"
echo "👉 Cek web admin: http://[IP-STB]:3000/admin"
echo "=========================================="
