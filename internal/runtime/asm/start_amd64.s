// Linux amd64 runtime stubs for volt.
//
// Provides:
//   _start       — program entry; calls main, forwards return → sys_exit
//   volt_write   — Linux sys_write(fd, buf, len)
//   volt_exit    — Linux sys_exit(code)
//   volt_spawn   — clone() a new thread that runs fn() then sys_exits
//
// Convention: the compiler always emits `main` as `define i64 @main()`,
// synthesizing `ret i64 0` if the user wrote a void main. We forward
// main's i64 result to sys_exit_group as the process exit code so all
// spawned threads are torn down.
//
// _start also captures argc / argv / envp from the initial stack so the
// `os` package can expose them later (os.Args, os.Getenv). Linux puts:
//   (rsp)        argc
//   8(rsp)       argv[0]
//   ...          argv[argc] = NULL
//                envp[0]
//                ...
//                envp[N] = NULL
// We stash argc as i64 and argv/envp as base pointers in BSS globals.

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
    // Capture argc / argv / envp before any stack alignment.
    movq    (%rsp),       %rax            // argc
    movq    %rax,         volt_argc(%rip)
    leaq    8(%rsp),      %rcx            // argv base
    movq    %rcx,         volt_argv(%rip)
    // envp = argv + (argc + 1) * 8
    leaq    8(%rcx,%rax,8), %rdx
    movq    %rdx,         volt_envp(%rip)

    andq    $-16, %rsp
    call    main
    // Preserve main's return value across the at-exit hook (which may
    // flush the memory profile). %rbx is callee-saved by the hook.
    movq    %rax, %rbx
    call    volt_runtime_at_program_exit
    movq    %rbx, %rdi      // exit code = main's return value
    movq    $231, %rax      // sys_exit_group (terminates whole process)
    syscall

.global volt_write
volt_write:
    movq    $1, %rax        // sys_write
    syscall
    ret

.global volt_exit
volt_exit:
    movq    $231, %rax      // sys_exit_group
    syscall
    // not reached

// volt_spawn(fn, arg1..arg6): clone a new thread that runs
// fn(arg1, arg2, arg3, arg4, arg5, arg6) then exits this thread.
//
// SysV: rdi = fn, rsi = arg1, rdx = arg2, rcx = arg3, r8 = arg4,
// r9 = arg5. arg6 arrives on the caller's stack at 16(%rbp) because
// SysV places the 7th positional argument there (rdi is fn, then 5
// args in regs, then the 7th total = arg6 on the stack).
//
// For fewer-arg fns pass 0s for the unused tail slots. v0.6 max 6
// args, matching the SysV register-arg ceiling for the receiving fn.
//
// Steps:
//   1. Stash fn + 6 args in callee-saved regs (mmap clobbers caller-saved).
//   2. mmap 1 MB stack.
//   3. Push (arg6, arg5, arg4, arg3, arg2, arg1, fn) so child pops fn,
//      then arg1..arg6 into rdi/rsi/rdx/rcx/r8/r9.
//   4. clone() with the standard pthread flags.
//   5. Parent returns child TID.
//   6. Child: pop into the SysV-arg regs, call, sys_exit.
.global volt_spawn
volt_spawn:
    pushq   %rbp
    movq    %rsp, %rbp
    pushq   %rbx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    subq    $16, %rsp           // local slots for arg5/arg6 (caller-saved)

    movq    %rdi, %r12          // fn
    movq    %rsi, %r13          // arg1
    movq    %rdx, %r14          // arg2
    movq    %rcx, %r15          // arg3
    movq    %r8,  %rbx          // arg4
    movq    %r9,  -8(%rbp)      // arg5 → stack slot (5 callee-saved
                                //   regs in use; spill arg5 here)
    movq    16(%rbp), %rax      // arg6 from caller's stack frame
    movq    %rax, -16(%rbp)

    // mmap(NULL, 1MB, RW, PRIVATE|ANON, -1, 0)
    movq    $9,        %rax
    xorq    %rdi,      %rdi
    movq    $1048576,  %rsi
    movq    $3,        %rdx
    movq    $0x22,     %r10
    movq    $-1,       %r8
    xorq    %r9,       %r9
    syscall

    addq    $1048576, %rax
    // Push (arg6, arg5, arg4, arg3, arg2, arg1, fn) — fn on top.
    movq    -16(%rbp), %rcx     // reload arg6
    subq    $8, %rax
    movq    %rcx, (%rax)        // arg6
    movq    -8(%rbp), %rcx      // reload arg5
    subq    $8, %rax
    movq    %rcx, (%rax)        // arg5
    subq    $8, %rax
    movq    %rbx, (%rax)        // arg4
    subq    $8, %rax
    movq    %r15, (%rax)        // arg3
    subq    $8, %rax
    movq    %r14, (%rax)        // arg2
    subq    $8, %rax
    movq    %r13, (%rax)        // arg1
    subq    $8, %rax
    movq    %r12, (%rax)        // fn

    movq    %rax,       %rsi
    movq    $0x00050F00,%rdi
    xorq    %rdx,       %rdx
    xorq    %r10,       %r10
    xorq    %r8,        %r8
    movq    $56,        %rax    // sys_clone
    syscall

    testq   %rax, %rax
    jz      .Lvolt_spawn_child

    addq    $16, %rsp
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rbx
    popq    %rbp
    ret

.Lvolt_spawn_child:
    popq    %rax                // fn
    popq    %rdi                // arg1
    popq    %rsi                // arg2
    popq    %rdx                // arg3
    popq    %rcx                // arg4
    popq    %r8                 // arg5
    popq    %r9                 // arg6
    callq   *%rax
    xorq    %rdi, %rdi
    movq    $60, %rax           // sys_exit (this thread only)
    syscall
