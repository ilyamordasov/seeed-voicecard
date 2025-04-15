# Оптимизированный Makefile для AC108 ALSA плагина на Orange Pi Zero 2W

CC ?= gcc
CFLAGS = -O2 -Wall -fPIC
LDFLAGS = -shared

# На Orange Pi Zero 2W всегда aarch64
LIB_DIR = /usr/lib/aarch64-linux-gnu/alsa-lib

TARGET = libasound_module_pcm_ac108.so
SRCS = ac108_plugin.c
OBJS = $(SRCS:.c=.o)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -I/usr/include/alsa -c -o $@ $<

clean:
	rm -f $(OBJS) $(TARGET)
