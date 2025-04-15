#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт должен быть запущен с правами root (используйте sudo)" 1>&2
   exit 1
fi

echo "=== Установка ReSpeaker 4-микрофонного массива для Orange Pi Zero 2W ==="
echo "Ядро: $(uname -r)"
echo "Архитектура: $(uname -m)"

# Проверка свободного места в /boot
boot_line=$(df -h | grep /boot | head -n 1)
if [ "x${boot_line}" = "x" ]; then
  echo "Предупреждение: раздел /boot не найден.."
else
  boot_space=$(echo $boot_line | awk '{print $4;}')
  free_space=$(echo "${boot_space%?}")
  unit="${boot_space: -1}"
  if [[ "$unit" = "K" ]]; then
    echo "Ошибка: Недостаточно свободного места ($boot_space) в разделе /boot"
    exit 1
  elif [[ "$unit" = "M" ]]; then
    if [ "$free_space" -lt "25" ]; then
      echo "Ошибка: Недостаточно свободного места ($boot_space) в разделе /boot"
      exit 1
    fi
  fi
fi

# Определение путей для overlay и конфигурации
if [ -d /boot/overlay-user ]; then
  OVERLAYS=/boot/overlay-user
elif [ -d /boot/dtb/allwinner/overlay ]; then
  OVERLAYS=/boot/dtb/allwinner/overlay
else
  echo "Создание директории для оверлеев..."
  mkdir -p /boot/overlay-user
  OVERLAYS=/boot/overlay-user
fi

CONFIG=/boot/armbianEnv.txt
echo "Используется директория оверлеев: $OVERLAYS"
echo "Конфигурационный файл: $CONFIG"

# Проверка и создание директории оверлеев
if [ ! -d $OVERLAYS ]; then
  echo "Создание директории оверлеев: $OVERLAYS"
  mkdir -p $OVERLAYS
  if [ $? -ne 0 ]; then
    echo "Не удалось создать директорию оверлеев: $OVERLAYS" 1>&2
    exit 1
  fi
fi

# Установка необходимых пакетов
echo "Установка необходимых пакетов..."
apt update -y
apt-get -y install git i2c-tools libasound2-plugins build-essential device-tree-compiler dkms

# Установка заголовков ядра
echo "Установка заголовков ядра..."
if ! dpkg -l | grep -q "linux-headers-$(uname -r)"; then
  apt-get -y install linux-headers-$(uname -r) || {
    echo "Не найдены специфичные заголовки ядра, пробуем установить общие заголовки..."
    apt-get -y install linux-headers-current-sunxi64 || {
      echo "Ошибка: Не удалось установить заголовки ядра"
      exit 1
    }
  }
fi

# Проверка правильной установки заголовков ядра
if [ ! -d "/lib/modules/$(uname -r)/build" ]; then
  echo "ОШИБКА: Заголовки ядра не установлены корректно"
  echo "Не найдена директория: /lib/modules/$(uname -r)/build"
  exit 1
fi

ver="0.3"
marker="0.0.0"

# Функция для установки модуля через DKMS
function install_module {
  local src=$1
  local mod=$2

  # Очистка предыдущих установок
  if [[ -d /var/lib/dkms/$mod/$ver/$marker ]]; then
    rmdir /var/lib/dkms/$mod/$ver/$marker
  fi

  if [[ -e /usr/src/$mod-$ver || -e /var/lib/dkms/$mod/$ver ]]; then
    dkms remove --force -m $mod -v $ver --all
    rm -rf /usr/src/$mod-$ver
  fi

  # Копирование исходников
  mkdir -p /usr/src/$mod-$ver
  cp -a $src/* /usr/src/$mod-$ver/

  # Адаптация для Orange Pi
  echo "Адаптация исходников модуля для Orange Pi Zero 2W..."
  
  # Исправление Makefile для Orange Pi Zero 2W
  if [ -f /usr/src/$mod-$ver/Makefile ]; then
    sed -i 's/MAKE\[\(.*\)\]="make -C $kernel_source_dir M=${dkms_tree}\/${PACKAGE_NAME}\/${PACKAGE_VERSION}\/build"/MAKE\[\1\]="make -C $kernel_source_dir M=${dkms_tree}\/${PACKAGE_NAME}\/${PACKAGE_VERSION}\/build ARCH=arm64 EXTRA_CFLAGS=-DCONFIG_SND_SOC_SEEED_VOICECARD"/' /usr/src/$mod-$ver/dkms.conf
  fi

  # Добавление и сборка модуля
  dkms add -m $mod -v $ver
  dkms build -k $(uname -r) -m $mod -v $ver && {
    dkms install --force -k $(uname -r) -m $mod -v $ver
  }

  mkdir -p /var/lib/dkms/$mod/$ver/$marker
}

# Создание DTS для 4-микрофонного массива
echo "Создание DTS файла для 4-микрофонного массива..."
mkdir -p orangepi/dtoverlay

cat > orangepi/dtoverlay/seeed-4mic-voicecard.dts <<EOF
/dts-v1/;
/plugin/;

/ {
    compatible = "allwinner,sun50i-h618";

    fragment@0 {
        target-path = "/";
        __overlay__ {
            ac108_clock: ac108_clock {
                compatible = "fixed-clock";
                #clock-cells = <0>;
                clock-frequency = <24000000>;
            };
        };
    };

    fragment@1 {
        target = <&i2c1>;
        __overlay__ {
            #address-cells = <1>;
            #size-cells = <0>;
            status = "okay";

            ac108_0: ac108@35 {
                compatible = "x-power,ac108_0";
                reg = <0x35>;
                #sound-dai-cells = <0>;
                data-protocol = <0>;
                status = "okay";
                clocks = <&ac108_clock>;
            };

            ac108_1: ac108@36 {
                compatible = "x-power,ac108_1";
                reg = <0x36>;
                #sound-dai-cells = <0>;
                data-protocol = <0>;
                status = "okay";
                clocks = <&ac108_clock>;
            };

            wm8960: wm8960@1a {
                compatible = "wlf,wm8960";
                reg = <0x1a>;
                #sound-dai-cells = <0>;
                status = "okay";
                clocks = <&ac108_clock>;
            };
        };
    };

    fragment@2 {
        target = <&i2s0>;
        __overlay__ {
            status = "okay";
            pinctrl-names = "default";
            sound-dai = <&wm8960>, <&ac108_0>, <&ac108_1>;
        };
    };

    fragment@3 {
        target-path = "/";
        __overlay__ {
            seeed_4mic_card: seeed_4mic_card {
                compatible = "simple-audio-card";
                simple-audio-card,name = "seeed-4mic-voicecard";
                simple-audio-card,format = "i2s";
                simple-audio-card,widgets =
                    "Microphone", "Microphone Array",
                    "Headphone", "Headphone Jack";
                simple-audio-card,routing =
                    "Headphone Jack", "HP_L",
                    "Headphone Jack", "HP_R";

                simple-audio-card,cpu {
                    sound-dai = <&i2s0>;
                };

                simple-audio-card,codec {
                    sound-dai = <&wm8960>, <&ac108_0>, <&ac108_1>;
                    system-clock-frequency = <24000000>;
                };
            };
        };
    };
};
EOF

# Компиляция DTS в DTBO
echo "Компиляция DTS в DTBO..."
dtc -@ -I dts -O dtb -o seeed-4mic-voicecard.dtbo orangepi/dtoverlay/seeed-4mic-voicecard.dts

# Установка модуля seeed-voicecard
echo "Установка модуля ядра через DKMS..."
install_module "./" "seeed-voicecard"

# Установка DTBO файла
echo "Установка DTBO файла в $OVERLAYS..."
cp -v seeed-4mic-voicecard.dtbo $OVERLAYS/

# Сборка и установка ALSA плагина для AC108
echo "Сборка и установка ALSA плагина для AC108..."
if [ -d ac108_plugin ]; then
  cd ac108_plugin
  make
  mkdir -p /usr/lib/aarch64-linux-gnu/alsa-lib/
  cp -v libasound_module_pcm_ac108.so /usr/lib/aarch64-linux-gnu/alsa-lib/
  cd ..
fi

# Настройка модулей ядра
echo "Настройка модулей ядра..."
grep -q "^snd-soc-seeed-voicecard$" /etc/modules || \
  echo "snd-soc-seeed-voicecard" >> /etc/modules
grep -q "^snd-soc-ac108$" /etc/modules || \
  echo "snd-soc-ac108" >> /etc/modules
grep -q "^snd-soc-wm8960$" /etc/modules || \
  echo "snd-soc-wm8960" >> /etc/modules

# Настройка оверлея в armbianEnv.txt
echo "Настройка оверлея в armbianEnv.txt..."
if [ -f $CONFIG ]; then
  # Обработка уже существующих оверлеев
  if grep -q "^overlays=" $CONFIG; then
    if ! grep -q "seeed-4mic-voicecard" $CONFIG; then
      sed -i 's/^overlays=\(.*\)/overlays=\1 seeed-4mic-voicecard/' $CONFIG
    fi
  else
    # Добавление строки с оверлеем если её нет
    echo "overlays=seeed-4mic-voicecard" >> $CONFIG
  fi

  # Включение I2C и I2S
  grep -q "^param_i2c1=on" $CONFIG || echo "param_i2c1=on" >> $CONFIG
  grep -q "^param_i2s=on" $CONFIG || echo "param_i2s=on" >> $CONFIG
else
  echo "Предупреждение: Конфигурационный файл $CONFIG не найден!"
fi

# Создание конфигурационных файлов
echo "Создание конфигурационных файлов..."
mkdir -p /etc/voicecard

# Создание ac108_asound.state для настройки 4-микрофонного массива
cat > /etc/voicecard/ac108_asound.state <<EOF
state.SEEED4MICVOICE {
	control.1 {
		iface MIXER
		name 'ADC PGA gain'
		value 31
		comment {
			access 'read write'
			type INTEGER
			count 1
			range '0 - 31'
		}
	}
	control.2 {
		iface MIXER
		name 'MIC1 boost gain'
		value 0
		comment {
			access 'read write'
			type INTEGER
			count 1
			range '0 - 7'
		}
	}
	control.3 {
		iface MIXER
		name 'MIC2 boost gain'
		value 0
		comment {
			access 'read write'
			type INTEGER
			count 1
			range '0 - 7'
		}
	}
	control.4 {
		iface MIXER
		name 'MIC3 boost gain'
		value 0
		comment {
			access 'read write'
			type INTEGER
			count 1
			range '0 - 7'
		}
	}
	control.5 {
		iface MIXER
		name 'MIC4 boost gain'
		value 0
		comment {
			access 'read write'
			type INTEGER
			count 1
			range '0 - 7'
		}
	}
	control.6 {
		iface MIXER
		name 'ADC volume'
		value 192
		comment {
			access 'read write'
			type INTEGER
			count 1
			range '0 - 255'
		}
	}
	control.7 {
		iface MIXER
		name 'ADCL volume'
		value 0
		comment {
			access 'read write'
			type INTEGER
			count 1
			range '0 - 15'
		}
	}
	control.8 {
		iface MIXER
		name 'ADCR volume'
		value 0
		comment {
			access 'read write'
			type INTEGER
			count 1
			range '0 - 15'
		}
	}
	control.9 {
		iface MIXER
		name 'ADC mixer gain'
		value 0
		comment {
			access 'read write'
			type INTEGER
			count 1
			range '0 - 15'
		}
	}
	control.10 {
		iface MIXER
		name 'PCM Playback Volume'
		value.0 190
		value.1 190
		comment {
			access 'read write'
			type INTEGER
			count 2
			range '0 - 255'
		}
	}
	control.11 {
		iface MIXER
		name 'Headphone Playback Volume'
		value.0 120
		value.1 120
		comment {
			access 'read write'
			type INTEGER
			count 2
			range '0 - 127'
		}
	}
	control.12 {
		iface MIXER
		name 'Headphone Playback Switch'
		value.0 true
		value.1 true
		comment {
			access 'read write'
			type BOOLEAN
			count 2
		}
	}
	control.13 {
		iface MIXER
		name 'Speaker Playback Volume'
		value.0 120
		value.1 120
		comment {
			access 'read write'
			type INTEGER
			count 2
			range '0 - 127'
		}
	}
	control.14 {
		iface MIXER
		name 'Speaker Playback Switch'
		value.0 false
		value.1 false
		comment {
			access 'read write'
			type BOOLEAN
			count 2
		}
	}
}
EOF

# Создание ALSA конфигурации для удобства использования
cat > /etc/asound.conf <<EOF
pcm.ac108 {
    type plug
    slave {
        pcm "hw:seeed4micvoicec"
        channels 4
        rate 48000
        format S16_LE
    }
}

pcm.mic_array {
    type plug
    slave {
        pcm "hw:seeed4micvoicec"
        channels 4
        rate 48000
        format S16_LE
    }
}

pcm.playback {
    type plug
    slave {
        pcm "hw:seeed4micvoicec"
        channels 2
        rate 48000
        format S16_LE
    }
}

pcm.!default {
    type asym
    playback.pcm "playback"
    capture.pcm "mic_array"
}
EOF

# Создание скрипта для инициализации карты
cat > /usr/bin/seeed-voicecard <<EOF
#!/bin/bash

# Скрипт для настройки 4-микрофонного массива на Orange Pi Zero 2W

# Загрузка настроек миксера
if [ -f /etc/voicecard/ac108_asound.state ]; then
    echo "Загрузка настроек AC108 микрофонного массива..."
    alsactl restore -f /etc/voicecard/ac108_asound.state
else
    echo "ОШИБКА: Файл настроек для AC108 не найден!"
    exit 1
fi

# Проверка наличия устройства
if aplay -l | grep -q "seeed-4mic-voicecard"; then
    echo "4-микрофонный массив успешно настроен"
else
    echo "ОШИБКА: Не обнаружен 4-микрофонный массив ReSpeaker"
    exit 1
fi

exit 0
EOF
chmod +x /usr/bin/seeed-voicecard

# Создание systemd сервиса
cat > /lib/systemd/system/seeed-voicecard.service <<EOF
[Unit]
Description=Seeed Voice Card 4-Mic Array
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/seeed-voicecard
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Активация сервиса
systemctl enable seeed-voicecard.service
systemctl start seeed-voicecard.service

# Создание udev правил для доступа к устройству
cat > /etc/udev/rules.d/91-seeed-voicecard.rules <<EOF
# Правила доступа к устройствам ReSpeaker 4-Mic Array
SUBSYSTEM=="sound", KERNEL=="controlC[0-9]*", ATTRS{id}=="seeed4micvoicec", MODE="0666"
SUBSYSTEM=="sound", KERNEL=="pcmC[0-9]*D[0-9]*c", ATTRS{id}=="seeed4micvoicec", MODE="0666"
SUBSYSTEM=="sound", KERNEL=="pcmC[0-9]*D[0-9]*p", ATTRS{id}=="seeed4micvoicec", MODE="0666"
EOF
udevadm control --reload-rules
udevadm trigger

echo "==================================================================="
echo "Установка ReSpeaker 4-Mic Array для Orange Pi Zero 2W завершена!"
echo "Пожалуйста, перезагрузите устройство для активации всех настроек:"
echo "sudo reboot"
echo "==================================================================="
echo "После перезагрузки проверьте работу устройства командами:"
echo "aplay -l           # Просмотр устройств воспроизведения"
echo "arecord -l         # Просмотр устройств записи"
echo "arecord -D mic_array -f S16_LE -r 48000 -c 4 test.wav  # Запись с 4 микрофонов"
echo "aplay test.wav     # Воспроизведение записи"
echo "==================================================================="
