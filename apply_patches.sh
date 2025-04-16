#!/bin/bash

# Скрипт для применения патчей для ReSpeaker 4-микрофонного массива на Orange Pi Zero 2W
# Для использования в репозитории seeed-voicecard

set -e  # Завершение скрипта при ошибках

# Проверка, запущен ли скрипт от имени root
if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт должен быть запущен от имени root (используйте sudo)" 1>&2
   exit 1
fi

# Определение текущей директории
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Директория скрипта: $SCRIPT_DIR"

# Определение директории репозитория seeed-voicecard
REPO_DIR=$(pwd)
echo "Директория репозитория: $REPO_DIR"

# Поиск необходимых файлов
SEEED_VOICECARD_C=$(find $REPO_DIR -name "seeed-voicecard.c" -type f | head -n 1)
SEEED_VOICECARD_SCRIPT=$(find $REPO_DIR -name "seeed-voicecard" -type f -not -path "*/\.*" | head -n 1)
AC108_C=$(find $REPO_DIR -name "*ac108*.c" -type f -not -path "*/ac108_plugin/*" | head -n 1)
WM8960_C=$(find $REPO_DIR -name "*wm8960*.c" -type f | head -n 1)
AC108_PLUGIN_DIR=$(find $REPO_DIR -type d -name "*ac108*plugin*" | head -n 1)

# Сообщение о найденных файлах
echo "Найдены следующие файлы:"
[ -n "$SEEED_VOICECARD_C" ] && echo "seeed-voicecard.c: $SEEED_VOICECARD_C" || echo "ОШИБКА: seeed-voicecard.c не найден!"
[ -n "$SEEED_VOICECARD_SCRIPT" ] && echo "seeed-voicecard script: $SEEED_VOICECARD_SCRIPT" || echo "ПРЕДУПРЕЖДЕНИЕ: seeed-voicecard скрипт не найден!"
[ -n "$AC108_C" ] && echo "AC108 driver: $AC108_C" || echo "ПРЕДУПРЕЖДЕНИЕ: AC108 драйвер не найден!"
[ -n "$WM8960_C" ] && echo "WM8960 driver: $WM8960_C" || echo "ПРЕДУПРЕЖДЕНИЕ: WM8960 драйвер не найден!"
[ -n "$AC108_PLUGIN_DIR" ] && echo "AC108 plugin directory: $AC108_PLUGIN_DIR" || echo "ПРЕДУПРЕЖДЕНИЕ: Директория плагина AC108 не найдена!"

# Создание директорий
mkdir -p $REPO_DIR/orangepi/dtoverlay
mkdir -p /etc/voicecard

# Копирование файлов
echo "Копирование файлов..."
cp -f "$SCRIPT_DIR/seeed-voicecard.c" "$SEEED_VOICECARD_C"
[ -n "$SEEED_VOICECARD_SCRIPT" ] && cp -f "$SCRIPT_DIR/seeed-voicecard" "$SEEED_VOICECARD_SCRIPT" && chmod +x "$SEEED_VOICECARD_SCRIPT"
cp -f "$SCRIPT_DIR/orangepi/dtoverlay/seeed-4mic-voicecard.dts" "$REPO_DIR/orangepi/dtoverlay/"
[ -n "$AC108_PLUGIN_DIR" ] && cp -f "$SCRIPT_DIR/ac108_plugin/Makefile" "$AC108_PLUGIN_DIR/"
cp -f "$SCRIPT_DIR/etc/voicecard/ac108_asound.state" "/etc/voicecard/"

# Создание ссылки на seeed-voicecard скрипт, если он не существует
if [ -z "$SEEED_VOICECARD_SCRIPT" ]; then
    echo "Создание нового скрипта seeed-voicecard в /usr/bin..."
    cp -f "$SCRIPT_DIR/seeed-voicecard" "/usr/bin/"
    chmod +x "/usr/bin/seeed-voicecard"
fi

# Отображение инструкций по ручному патчингу других файлов
echo "==========================================================================="
echo "Применение файлов завершено. Необходимо вручную применить следующие патчи:"
echo "1. Для AC108 драйвера ($AC108_C):"
echo "   Смотрите инструкции в файле $SCRIPT_DIR/ac108_orangepi_patch.txt"
echo "2. Для WM8960 драйвера ($WM8960_C):"
echo "   Смотрите инструкции в файле $SCRIPT_DIR/wm8960_orangepi_patch.txt"
echo "==========================================================================="
echo "После этого запустите компиляцию и установку драйвера:"
echo "sudo ./install.sh"
echo "sudo reboot"
echo "==========================================================================="

exit 0
