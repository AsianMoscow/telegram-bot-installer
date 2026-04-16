#!/bin/bash
set -e

echo "=== Telegram Bot Installer (stable v2) ==="

# --- root check ---

if [ "$EUID" -ne 0 ]; then
echo "❌ Запусти через sudo"
exit 1
fi

# --- input ---

read -p "Имя пользователя бота [telegram]: " BOT_USER
BOT_USER=${BOT_USER:-telegram}

read -p "Имя сервиса [telegram_bot]: " SERVICE_NAME
SERVICE_NAME=${SERVICE_NAME:-telegram_bot}

read -p "Токен бота: " BOT_TOKEN

BOT_DIR=$(pwd)

echo ""
echo "📦 Папка: $BOT_DIR"
echo "👤 Пользователь: $BOT_USER"
echo "⚙️ Сервис: $SERVICE_NAME"
echo ""

# --- install deps ---

echo "=== Установка зависимостей системы ==="
apt update -y
apt install -y python3 python3-venv python3-pip

# --- user ---

echo "=== Пользователь ==="
if ! id "$BOT_USER" &>/dev/null; then
adduser --disabled-password --gecos "" $BOT_USER
fi

# --- permissions ---

chown -R $BOT_USER:$BOT_USER $BOT_DIR

# --- venv ---

echo "=== venv ==="
sudo -u $BOT_USER python3 -m venv $BOT_DIR/venv

# --- pip deps ---

echo "=== Python зависимости ==="
sudo -u $BOT_USER $BOT_DIR/venv/bin/pip install --upgrade pip
sudo -u $BOT_USER $BOT_DIR/venv/bin/pip install aiogram python-dotenv

# --- .env ---

echo "=== .env ==="
cat > $BOT_DIR/.env <<EOF
BOT_TOKEN=$BOT_TOKEN
EOF

chown $BOT_USER:$BOT_USER $BOT_DIR/.env
chmod 600 $BOT_DIR/.env

# --- bot.py (ПРАВИЛЬНЫЙ, БЕЗ ОШИБОК ОТСТУПОВ) ---

echo "=== bot.py ==="

cat > $BOT_DIR/bot.py <<'EOF'
import asyncio
import logging
import os
from aiogram import Bot, Dispatcher
from aiogram.types import Message
from aiogram.filters import Command
from dotenv import load_dotenv

load_dotenv()

TOKEN = os.getenv("BOT_TOKEN")

if not TOKEN:
raise RuntimeError("BOT_TOKEN not found in .env")

logging.basicConfig(
level=logging.INFO,
filename="bot.log",
format="%(asctime)s - %(levelname)s - %(message)s"
)

bot = Bot(token=TOKEN)
dp = Dispatcher()

@dp.message(Command("start"))
async def start(message: Message):
await message.answer("Бот запущен 🚀")

async def main():
await dp.start_polling(bot)

if **name** == "**main**":
asyncio.run(main())
EOF

chown $BOT_USER:$BOT_USER $BOT_DIR/bot.py

# --- systemd ---

echo "=== systemd ==="

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

# --- restart systemd ---

echo "=== запуск ==="

systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME

echo ""
echo "✅ ГОТОВО"
echo "📊 статус: systemctl status $SERVICE_NAME"
echo "📜 логи: journalctl -u $SERVICE_NAME -f"
