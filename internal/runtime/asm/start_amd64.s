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

.global _start
.text

_start:
    andq    $-16, %rsp
    call    main
    movq    %rax, %rdi      // exit code = main's return value
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

// volt_spawn(fn, arg1, arg2): clone a new thread that runs
// fn(arg1, arg2) then exits this thread.
//
// SysV: rdi = fn, rsi = arg1, rdx = arg2. For zero-arg fn pass arg1=0;
// for 1-arg fn pass arg2=0. v0.5 max 2 args (covers most concurrent
// patterns: chan in, chan out / done).
//
// Steps:
//   1. mmap 1 MB stack.
//   2. Push (arg2, arg1, fn) so child pops fn → rax, arg1 → rdi, arg2 → rsi.
//   3. clone() with the standard pthread flags.
//   4. Parent returns child TID.
//   5. Child: pop, call, sys_exit.
.global volt_spawn
volt_spawn:
    pushq   %rbp
    movq    %rsp, %rbp
    pushq   %r12
    pushq   %r13
    pushq   %r14

    movq    %rdi, %r12          // fn
    movq    %rsi, %r13          // arg1
    movq    %rdx, %r14          // arg2

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
    // Push (arg2, arg1, fn) — fn ends up on top.
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

    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rbp
    ret

.Lvolt_spawn_child:
    popq    %rax                // fn
    popq    %rdi                // arg1
    popq    %rsi                // arg2
    callq   *%rax
    xorq    %rdi, %rdi
    movq    $60, %rax           // sys_exit (this thread only)
    syscall
