#!/bin/bash
set -e

echo "=== Telegram Bot Installer (GitHub-based v3) ==="

if [ "$EUID" -ne 0 ]; then
echo "❌ Запусти через sudo"
exit 1
fi

# --- input ---

read -p "GitHub RAW URL (folder root, example: https://github.com/AsianMoscow/telegram-bot-installer): " REPO_URL
read -p "Имя пользователя [telegram]: " BOT_USER
BOT_USER=${BOT_USER:-telegram}

read -p "Имя сервиса [telegram_bot]: " SERVICE_NAME
SERVICE_NAME=${SERVICE_NAME:-telegram_bot}

read -p "BOT TOKEN: " BOT_TOKEN

BOT_DIR=$(pwd)

echo ""
echo "📦 DIR: $BOT_DIR"
echo "👤 USER: $BOT_USER"
echo "🌐 REPO: $REPO_URL"
echo ""

# --- deps ---

apt update -y
apt install -y python3 python3-venv python3-pip curl

# --- user ---

if ! id "$BOT_USER" &>/dev/null; then
adduser --disabled-password --gecos "" $BOT_USER
fi

# --- permissions ---

chown -R $BOT_USER:$BOT_USER $BOT_DIR

# --- venv ---

sudo -u $BOT_USER python3 -m venv $BOT_DIR/venv

# --- download bot code ---

echo "=== Downloading bot code ==="

curl -fsSL "$REPO_URL/bot.py" -o $BOT_DIR/bot.py

# optional requirements

if curl --output /dev/null --silent --head --fail "$REPO_URL/requirements.txt"; then
curl -fsSL "$REPO_URL/requirements.txt" -o $BOT_DIR/requirements.txt
sudo -u $BOT_USER $BOT_DIR/venv/bin/pip install --upgrade pip
sudo -u $BOT_USER $BOT_DIR/venv/bin/pip install -r $BOT_DIR/requirements.txt
else
sudo -u $BOT_USER $BOT_DIR/venv/bin/pip install --upgrade pip
sudo -u $BOT_USER $BOT_DIR/venv/bin/pip install aiogram python-dotenv
fi

# --- .env ---

echo "=== .env ==="

cat > $BOT_DIR/.env <<EOF
BOT_TOKEN=$BOT_TOKEN
EOF

chown $BOT_USER:$BOT_USER $BOT_DIR/.env
chmod 600 $BOT_DIR/.env

# --- systemd ---

echo "=== systemd service ==="

cat > /etc/systemd/system/$SERVICE_NAME.service <<EOF
[Unit]
Description=Telegram Bot ($SERVICE_NAME)
After=network.target

[Service]
User=$BOT_USER
WorkingDirectory=$BOT_DIR
ExecStart=$BOT_DIR/venv/bin/python $BOT_DIR/bot.py
Restart=always
RestartSec=5
EnvironmentFile=$BOT_DIR/.env

StandardOutput=append:$BOT_DIR/stdout.log
StandardError=append:$BOT_DIR/stderr.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME

echo ""
echo "✅ DONE"
echo "📊 status: systemctl status $SERVICE_NAME"
echo "📜 logs: journalctl -u $SERVICE_NAME -f"
