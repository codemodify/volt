// Linux arm64 (aarch64) runtime stubs for volt.
//
// Provides:
//   _start       — program entry; calls main, forwards return → sys_exit_group
//   volt_write   — Linux sys_write(fd, buf, len)
//   volt_exit    — Linux sys_exit_group(code)
//   volt_spawn   — clone() a new thread that runs fn(arg1, arg2) then sys_exits
//
// arm64 syscall ABI: number in x8; args x0..x5; return in x0; instruction `svc #0`.
// arm64 syscall numbers differ from amd64:
//   write = 64, exit = 93, exit_group = 94, clone = 220, mmap = 222,
//   futex = 98, nanosleep = 101.

// argc/argv/envp captured at process entry, exposed via BSS globals
// so the `os` package can serve os.Args / os.Getenv.
.global volt_argc
.global volt_argv
.global volt_envp
.bss
.align 8
volt_argc: .skip 8
volt_argv: .skip 8
volt_envp: .skip 8

.global _start
.text

_start:
    // Capture argc / argv / envp before doing anything else.
    ldr     x0, [sp]              // argc
    adrp    x9, volt_argc
    add     x9, x9, :lo12:volt_argc
    str     x0, [x9]
    add     x1, sp, #8            // argv base
    adrp    x9, volt_argv
    add     x9, x9, :lo12:volt_argv
    str     x1, [x9]
    // envp = argv + (argc + 1) * 8 → sp + 8 + (argc+1)*8 → sp + (argc+2)*8
    add     x2, x0, #2
    lsl     x2, x2, #3
    add     x2, sp, x2
    adrp    x9, volt_envp
    add     x9, x9, :lo12:volt_envp
    str     x2, [x9]

    bl      main
    // Preserve main's return value across the at-exit hook (which may
    // flush the memory profile). x19 is callee-saved by the hook.
    mov     x19, x0
    bl      volt_runtime_at_program_exit
    mov     x0, x19             // restore main's return value → exit code
    mov     x8, #94             // sys_exit_group
    svc     #0

.global volt_write
volt_write:
    mov     x8, #64             // sys_write
    svc     #0
    ret

.global volt_exit
volt_exit:
    mov     x8, #94             // sys_exit_group
    svc     #0
    // not reached

// volt_spawn(fn, arg1..arg6): clone a new thread that runs
// fn(arg1, arg2, arg3, arg4, arg5, arg6) then sys_exits this thread.
//
// arm64 AAPCS: x0..x7 hold the first 8 register args. fn is in x0;
// args1..6 in x1..x6. All 7 values fit in registers; no stack
// argument fixup needed (unlike amd64's 7th positional).
.global volt_spawn
volt_spawn:
    // Frame
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    // Caller-saved across syscalls — save fn/arg1..arg6 in callee-saved regs.
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    stp     x23, x24, [sp, #-16]!
    stp     x25, x26, [sp, #-16]!

    mov     x19, x0             // fn
    mov     x20, x1             // arg1
    mov     x21, x2             // arg2
    mov     x22, x3             // arg3
    mov     x23, x4             // arg4
    mov     x24, x5             // arg5
    mov     x25, x6             // arg6

    // mmap(NULL, 1MB, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
    mov     x0,  #0
    mov     x1,  #0x100000      // 1 MB
    mov     x2,  #3             // PROT_READ|PROT_WRITE
    mov     x3,  #0x22          // MAP_PRIVATE|MAP_ANONYMOUS
    mov     x4,  #-1
    mov     x5,  #0
    mov     x8,  #222           // sys_mmap
    svc     #0
    // x0 = mmap base. Top = base + 1MB.
    add     x0,  x0,  #0x100000

    // Push (arg6, arg5, arg4, arg3, arg2, arg1, fn) — fn ends up on top.
    sub     x0,  x0,  #8
    str     x25, [x0]           // arg6
    sub     x0,  x0,  #8
    str     x24, [x0]           // arg5
    sub     x0,  x0,  #8
    str     x23, [x0]           // arg4
    sub     x0,  x0,  #8
    str     x22, [x0]           // arg3
    sub     x0,  x0,  #8
    str     x21, [x0]           // arg2
    sub     x0,  x0,  #8
    str     x20, [x0]           // arg1
    sub     x0,  x0,  #8
    str     x19, [x0]           // fn

    // clone(flags, stack, ptid, tls, ctid)
    mov     x1,  x0             // stack
    movz    x0,  #0x0F00        // low 16 bits of flags
    movk    x0,  #0x0005, lsl #16 // high bits — total 0x50F00
    mov     x2,  #0             // ptid
    mov     x3,  #0             // tls
    mov     x4,  #0             // ctid
    mov     x8,  #220           // sys_clone
    svc     #0

    cbz     x0,  .Lvolt_spawn_child

    // Parent: restore and return.
    ldp     x25, x26, [sp], #16
    ldp     x23, x24, [sp], #16
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

.Lvolt_spawn_child:
    // Pop fn → x9, arg1..arg6 → x0..x5
    ldr     x9,  [sp], #8
    ldr     x0,  [sp], #8
    ldr     x1,  [sp], #8
    ldr     x2,  [sp], #8
    ldr     x3,  [sp], #8
    ldr     x4,  [sp], #8
    ldr     x5,  [sp], #8
    blr     x9
    mov     x0,  #0
    mov     x8,  #93            // sys_exit (this thread only)
    svc     #0
