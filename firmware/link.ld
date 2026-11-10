/* Memory map of QEMU's "generic-cortex-m" machine */
MEMORY
{
    FLASH (rx)  : ORIGIN = 0x00000000, LENGTH = 256K
    SRAM  (rwx) : ORIGIN = 0x20000000, LENGTH = 64K
}

ENTRY(Reset_Handler)

_estack = ORIGIN(SRAM) + LENGTH(SRAM);   /* initial stack pointer */

SECTIONS
{
    .text :
    {
        KEEP(*(.isr_vector))             /* vector table must be first */
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);
    } > FLASH

    _sidata = LOADADDR(.data);           /* .data initial values live in flash */

    .data :
    {
        . = ALIGN(4);
        _sdata = .;
        *(.data*)
        . = ALIGN(4);
        _edata = .;
    } > SRAM AT > FLASH

    .bss (NOLOAD) :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > SRAM
}
