#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "Этот скрипт должен быть запущен с правами root (используйте sudo)" 1>&2
    exit 1
fi

echo "=== Удаление ReSpeaker 4-Mic Array с Orange Pi Zero 2W ==="

# Остановка и удаление сервиса
systemctl stop seeed-voicecard
systemctl disable seeed-voicecard
rm -f /lib/systemd/system/seeed-voicecard.service
rm -f /usr/bin/seeed-voicecard

# Удаление модулей ядра через DKMS
dkms remove seeed-voicecard/0.3 --all || true
rm -rf /usr/src/seeed-voicecard-0.3/

# Удаление ALSA плагинов
rm -f /usr/lib/aarch64-linux-gnu/alsa-lib/libasound_module_pcm_ac108.so

# Удаление конфигурационных файлов
rm -rf /etc/voicecard
rm -f /etc/asound.conf
rm -f /etc/udev/rules.d/91-seeed-voicecard.rules

# Определение путей для оверлеев
OVERLAYS=""
if [ -d /boot/overlay-user ]; then
    OVERLAYS=/boot/overlay-user
elif [ -d /boot/dtb/allwinner/overlay ]; then
    OVERLAYS=/boot/dtb/allwinner/overlay
fi

# Удаление файлов device tree
if [ -n "$OVERLAYS" ]; then
    rm -f $OVERLAYS/seeed-4mic-voicecard.dtbo
fi

# Очистка armbianEnv.txt
CONFIG=/boot/armbianEnv.txt
if [ -f $CONFIG ]; then
    sed -i 's/seeed-4mic-voicecard//g' $CONFIG
    sed -i 's/  / /g' $CONFIG # Удаление двойных пробелов
fi

# Удаление модулей из /etc/modules
sed -i '/snd-soc-seeed-voicecard/d' /etc/modules
sed -i '/snd-soc-ac108/d' /etc/modules
sed -i '/snd-soc-wm8960/d' /etc/modules

echo "Удаление завершено. Пожалуйста, перезагрузите Orange Pi Zero 2W."
