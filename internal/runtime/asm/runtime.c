// volt runtime: minimal C implementation, no libc.
//
// Compiled with `clang -nostdlib -nostartfiles -fno-builtin -c`.
// Linked alongside user IR + start_amd64.s.
//
// Exposes:
//   void*  volt_alloc(i64 size)               — thread-safe bump allocator
//   void*  volt_chan_new(i64 cap)             — allocate a channel
//   void   volt_chan_send(void* ch, i64 v)    — blocks if full
//   i64    volt_chan_recv(void* ch)           — blocks if empty
//   (volt_spawn is implemented in start_amd64.s)
//
// Concurrency: uses CAS + futex(WAIT/WAKE) for the channel's mutex
// and not-full/not-empty condition variables, so send and recv block
// across real OS threads spawned by volt_spawn.

typedef long          i64;
typedef int           i32;
typedef unsigned long u64;

// ---------------------------------------------------------------------
// Static heap + thread-safe bump allocator
// ---------------------------------------------------------------------

static char volt_heap[16 * 1024 * 1024]; // 16 MB BSS
static u64  volt_heap_pos = 0;

static void volt_die(void) {
    register i64 rax __asm__("rax") = 231; // sys_exit_group
    register i64 rdi __asm__("rdi") = 1;
    __asm__ volatile("syscall" : : "r"(rax), "r"(rdi) : "rcx", "r11", "memory");
    __builtin_unreachable();
}

void* volt_alloc(i64 size) {
    if (size <= 0) return (void*)0;
    u64 aligned = ((u64)size + 7u) & ~7u;
    u64 cur = __atomic_fetch_add(&volt_heap_pos, aligned, __ATOMIC_RELAXED);
    if (cur + aligned > sizeof(volt_heap)) {
        volt_die();
    }
    return (void*)((u64)volt_heap + cur);
}

// ---------------------------------------------------------------------
// futex-based mutex + condvar
// ---------------------------------------------------------------------

#define FUTEX_WAIT 0
#define FUTEX_WAKE 1

static i64 sys_futex(i32* uaddr, i32 op, i32 val) {
    register i64 rax __asm__("rax") = 202;
    register i64 rdi __asm__("rdi") = (i64)uaddr;
    register i64 rsi __asm__("rsi") = op;
    register i64 rdx __asm__("rdx") = val;
    register i64 r10 __asm__("r10") = 0;
    register i64 r8  __asm__("r8")  = 0;
    register i64 r9  __asm__("r9")  = 0;
    __asm__ volatile(
        "syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10), "r"(r8), "r"(r9)
        : "rcx", "r11", "memory");
    return rax;
}

typedef struct { i32 state; } mutex_t; // 0=free, 1=locked, 2=locked+waiters
typedef struct { i32 seq;   } cond_t;

static void mutex_lock(mutex_t* m) {
    i32 expected = 0;
    if (__atomic_compare_exchange_n(&m->state, &expected, 1, 0,
            __ATOMIC_ACQUIRE, __ATOMIC_RELAXED)) {
        return;
    }
    for (;;) {
        if (__atomic_exchange_n(&m->state, 2, __ATOMIC_ACQUIRE) == 0) {
            return;
        }
        sys_futex(&m->state, FUTEX_WAIT, 2);
    }
}

static void mutex_unlock(mutex_t* m) {
    i32 prev = __atomic_exchange_n(&m->state, 0, __ATOMIC_RELEASE);
    if (prev == 2) {
        sys_futex(&m->state, FUTEX_WAKE, 1);
    }
}

static void cond_wait(cond_t* c, mutex_t* m) {
    i32 seq = __atomic_load_n(&c->seq, __ATOMIC_ACQUIRE);
    mutex_unlock(m);
    sys_futex(&c->seq, FUTEX_WAIT, seq);
    mutex_lock(m);
}

static void cond_signal(cond_t* c) {
    __atomic_add_fetch(&c->seq, 1, __ATOMIC_RELEASE);
    sys_futex(&c->seq, FUTEX_WAKE, 1);
}

// ---------------------------------------------------------------------
// Blocking channel (single element type = i64)
// ---------------------------------------------------------------------

typedef struct {
    mutex_t  lock;
    cond_t   not_full;
    cond_t   not_empty;
    i64      cap;
    i64      len;
    i64      head;
    i64      tail;
    i64      closed;
    i64*     buf;
} chan_i64_t;

void* volt_chan_new(i64 cap) {
    if (cap <= 0) cap = 1;
    chan_i64_t* c = (chan_i64_t*)volt_alloc((i64)sizeof(chan_i64_t));
    c->lock.state    = 0;
    c->not_full.seq  = 0;
    c->not_empty.seq = 0;
    c->cap    = cap;
    c->len    = 0;
    c->head   = 0;
    c->tail   = 0;
    c->closed = 0;
    c->buf    = (i64*)volt_alloc(cap * (i64)sizeof(i64));
    return (void*)c;
}

void volt_chan_send(void* ch_, i64 v) {
    chan_i64_t* c = (chan_i64_t*)ch_;
    mutex_lock(&c->lock);
    while (c->len >= c->cap) {
        cond_wait(&c->not_full, &c->lock);
    }
    c->buf[c->tail] = v;
    c->tail = (c->tail + 1) % c->cap;
    c->len++;
    cond_signal(&c->not_empty);
    mutex_unlock(&c->lock);
}

i64 volt_chan_recv(void* ch_) {
    chan_i64_t* c = (chan_i64_t*)ch_;
    mutex_lock(&c->lock);
    while (c->len == 0) {
        cond_wait(&c->not_empty, &c->lock);
    }
    i64 v = c->buf[c->head];
    c->head = (c->head + 1) % c->cap;
    c->len--;
    cond_signal(&c->not_full);
    mutex_unlock(&c->lock);
    return v;
}
