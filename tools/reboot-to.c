/* Freestanding aarch64 helper: reboot with the "bootloader" argument (no libc needed). */
static long sys3(long n, long a, long b, long c, long d) {
    register long x8 __asm__("x8") = n;
    register long x0 __asm__("x0") = a;
    register long x1 __asm__("x1") = b;
    register long x2 __asm__("x2") = c;
    register long x3 __asm__("x3") = d;
    __asm__ volatile("svc 0" : "+r"(x0) : "r"(x8), "r"(x1), "r"(x2), "r"(x3) : "memory");
    return x0;
}
void _start(void) {
    static const char arg[] = "bootloader";
    sys3(81, 0, 0, 0, 0);                                   /* sync */
    sys3(142, 0xfee1dead, 672274793, 0xA1B2C3D4, (long)arg); /* reboot(RESTART2, "bootloader") */
    sys3(93, 1, 0, 0, 0);                                   /* exit(1) if it failed */
    for (;;) { }
}
