# Patches aplicados ao driver `xmm7360.c`

O driver vem de [xmm7360/xmm7360-pci](https://github.com/xmm7360/xmm7360-pci).
Para compilar em kernels modernos (testado em 6.14 e 6.17), foram aplicadas as
correções abaixo. Elas estão **version-guarded** (`LINUX_VERSION_CODE`), então o
mesmo arquivo continua compilando em kernels antigos.

## 1. Assinatura de `tty_operations.write` (kernel ≥ 6.6)
No kernel 6.6 a assinatura mudou (`int` → `ssize_t`, `unsigned char` → `u8`,
`int` → `size_t`):

```c
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 6, 0)
static ssize_t xmm7360_tty_write(struct tty_struct *tty,
                     const u8 *buffer, size_t count)
#else
static int xmm7360_tty_write(struct tty_struct *tty,
                     const unsigned char *buffer, int count)
#endif
```

## 2. `hrtimer_init()` removido (kernel ≥ 6.16)
No kernel 6.16 `hrtimer_init()` foi removido; usa-se `hrtimer_setup()` (o
callback passou a ser o 2º argumento). Em `xmm7360_net_setup`:

```c
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 16, 0)
    hrtimer_setup(&xn->deadline, xmm7360_net_deadline_cb,
                  CLOCK_MONOTONIC, HRTIMER_MODE_REL);
#else
    hrtimer_init(&xn->deadline, CLOCK_MONOTONIC, HRTIMER_MODE_REL);
    xn->deadline.function = xmm7360_net_deadline_cb;
#endif
```

## 3. Função `xmm7360_dev_init_work` tornada `static`
Para silenciar `-Werror=missing-prototypes` em toolchains recentes:

```c
static void xmm7360_dev_init_work(struct work_struct *work)
```

> Os demais avisos de compilação (`no-previous-prototype`, comparação de
> `td_ring` sempre não-nula) são inofensivos e não impedem o build.
