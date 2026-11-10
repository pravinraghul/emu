/* Hello World over UART0 of QEMU's "generic-cortex-m" machine. */
#include <stdint.h>

/* Arm CMSDK APB UART at 0x40004000 */
#define UART0_BASE      0x40004000u
#define UART_DATA       (*(volatile uint32_t *)(UART0_BASE + 0x00))
#define UART_STATE      (*(volatile uint32_t *)(UART0_BASE + 0x04))
#define UART_CTRL       (*(volatile uint32_t *)(UART0_BASE + 0x08))
#define UART_BAUDDIV    (*(volatile uint32_t *)(UART0_BASE + 0x10))

#define UART_STATE_TXFULL   (1u << 0)
#define UART_CTRL_TX_EN     (1u << 0)

#define SYSCLK_HZ       25000000u
#define BAUD            115200u

static void uart_init(void)
{
    UART_BAUDDIV = SYSCLK_HZ / BAUD;    /* must be >= 16 */
    UART_CTRL = UART_CTRL_TX_EN;
}

static void uart_putc(char c)
{
    while (UART_STATE & UART_STATE_TXFULL) {
    }
    UART_DATA = (uint32_t)c;
}

static void uart_puts(const char *s)
{
    while (*s) {
        if (*s == '\n') {
            uart_putc('\r');
        }
        uart_putc(*s++);
    }
}

int main(void)
{
    uart_init();
    uart_puts("Hello World\n");
    for (;;) {
    }
}
