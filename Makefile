# Оптимизированный Makefile для ReSpeaker 4-Mic Array на Orange Pi Zero 2W

ARCH := aarch64
EXTRA_CFLAGS += -DCONFIG_SND_SOC_SEEED_VOICECARD -DCONFIG_ORANGEPI

obj-m += snd-soc-seeed-voicecard.o
obj-m += snd-soc-ac108.o
obj-m += snd-soc-wm8960.o

snd-soc-seeed-voicecard-objs := seeed-voicecard.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules ARCH=arm64

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean

install:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules_install ARCH=arm64
	depmod -a

# Компиляция DTBO файла для 4-микрофонного массива
dtbo:
	dtc -@ -I dts -O dtb -o seeed-4mic-voicecard.dtbo orangepi/dtoverlay/seeed-4mic-voicecard.dts
