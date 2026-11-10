/* Minimal Cortex-M startup: vector table + reset handler. */
#include <stdint.h>

extern uint32_t _estack, _sidata, _sdata, _edata, _sbss, _ebss;
extern int main(void);

void Reset_Handler(void);

static void Default_Handler(void)
{
    for (;;) {
    }
}

void NMI_Handler(void)       __attribute__((weak, alias("Default_Handler")));
void HardFault_Handler(void) __attribute__((weak, alias("Default_Handler")));
void SVC_Handler(void)       __attribute__((weak, alias("Default_Handler")));
void PendSV_Handler(void)    __attribute__((weak, alias("Default_Handler")));
void SysTick_Handler(void)   __attribute__((weak, alias("Default_Handler")));
void UART0_IRQHandler(void)  __attribute__((weak, alias("Default_Handler")));

__attribute__((section(".isr_vector"), used))
const void *const vector_table[] = {
    &_estack,               /*  0: initial stack pointer */
    Reset_Handler,          /*  1: reset */
    NMI_Handler,            /*  2 */
    HardFault_Handler,      /*  3 */
    0, 0, 0, 0, 0, 0, 0,    /*  4-10: reserved / not used on M0 */
    SVC_Handler,            /* 11 */
    0, 0,                   /* 12-13 */
    PendSV_Handler,         /* 14 */
    SysTick_Handler,        /* 15 */
    UART0_IRQHandler,       /* 16: IRQ 0 */
};

void Reset_Handler(void)
{
    uint32_t *src = &_sidata, *dst = &_sdata;

    while (dst < &_edata) {     /* copy .data from flash to SRAM */
        *dst++ = *src++;
    }
    for (dst = &_sbss; dst < &_ebss; dst++) {   /* zero .bss */
        *dst = 0;
    }
    main();
    for (;;) {
    }
}
