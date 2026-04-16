#!/bin/bash

set -e

echo "=== Установка Telegram бота (в текущую директорию) ==="

# --- Проверка root ---

if [ "$EUID" -ne 0 ]; then
echo "Запусти скрипт через sudo"
exit 1
fi

# --- Ввод ---

read -p "Имя пользователя для бота [telegram]: " BOT_USER
BOT_USER=${BOT_USER:-telegram}

read -p "Название сервиса [telegram_bot]: " SERVICE_NAME
SERVICE_NAME=${SERVICE_NAME:-telegram_bot}

read -p "Токен бота: " BOT_TOKEN

BOT_DIR=$(pwd)

echo ""
echo "=== Параметры ==="
echo "Папка: $BOT_DIR"
echo "Пользователь: $BOT_USER"
echo "Сервис: $SERVICE_NAME"
echo ""

# --- Создание пользователя ---

echo "=== Пользователь ==="
if id "$BOT_USER" &>/dev/null; then
echo "Пользователь уже существует"
else
adduser --disabled-password --gecos "" $BOT_USER
fi

# --- Установка зависимостей ---

echo "=== Установка пакетов ==="
apt update
apt install -y python3 python3-venv python3-pip

# --- Права на папку ---

echo "=== Назначение прав ==="
chown -R $BOT_USER:$BOT_USER $BOT_DIR

# --- VENV ---

echo "=== Виртуальное окружение ==="
sudo -u $BOT_USER python3 -m venv $BOT_DIR/venv

echo "=== Установка библиотек ==="
sudo -u $BOT_USER $BOT_DIR/venv/bin/pip install --upgrade pip
sudo -u $BOT_USER $BOT_DIR/venv/bin/pip install aiogram python-dotenv

# --- .env ---

echo "=== Создание .env ==="
cat <<EOF > $BOT_DIR/.env
BOT_TOKEN=$BOT_TOKEN
EOF

chown $BOT_USER:$BOT_USER $BOT_DIR/.env
chmod 600 $BOT_DIR/.env

# --- bot.py ---

if [ ! -f "$BOT_DIR/bot.py" ]; then
echo "=== Создание bot.py ==="
cat <<EOF > $BOT_DIR/bot.py
import asyncio
import logging
import os
from aiogram import Bot, Dispatcher
from aiogram.types import Message
from aiogram.filters import Command
from dotenv import load_dotenv

load_dotenv()

TOKEN = os.getenv("BOT_TOKEN")

logging.basicConfig(
level=logging.INFO,
filename="bot.log",
format="%(asctime)s - %(levelname)s - %(message)s"
)

bot = Bot(token=TOKEN)
dp = Dispatcher()

@dp.message(Command("start"))
async def start(message: Message):
await message.answer("Бот работает 🚀")

async def main():
await dp.start_polling(bot)

if **name** == "**main**":
asyncio.run(main())
EOF
fi

chown $BOT_USER:$BOT_USER $BOT_DIR/bot.py

# --- systemd ---

echo "=== Создание systemd сервиса ==="

cat <<EOF > /etc/systemd/system/$SERVICE_NAME.service
[Unit]
Description=Telegram Bot ($BOT_DIR)
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

# --- Запуск ---

echo "=== Запуск ==="
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME

echo ""
echo "=== ГОТОВО ==="
echo "Папка: $BOT_DIR"
echo "Пользователь: $BOT_USER"
echo ""
echo "Статус: systemctl status $SERVICE_NAME"
echo "Логи: journalctl -u $SERVICE_NAME -f"
