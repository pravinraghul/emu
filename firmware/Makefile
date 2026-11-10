# Bare-metal Hello World for QEMU "generic-cortex-m".
# CPU can be overridden: make CPU=cortex-m4   (must match QEMU's -cpu)
CROSS   ?= arm-none-eabi-
CC      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
SIZE    := $(CROSS)size
CPU     ?= cortex-m3

CFLAGS  := -mcpu=$(CPU) -mthumb -O2 -g -Wall -Wextra -ffreestanding -ffunction-sections
LDFLAGS := -nostdlib -T link.ld -Wl,--gc-sections -Wl,-Map=hello.map

all: hello.elf hello.bin

hello.elf: startup.c main.c link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) startup.c main.c -o $@
	$(SIZE) $@

hello.bin: hello.elf
	$(OBJCOPY) -O binary $< $@

clean:
	rm -f hello.elf hello.bin hello.map

.PHONY: all clean
