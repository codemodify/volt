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
typedef short         i16;
typedef signed char   i8;
typedef unsigned long u64;

// Arch-conditional Linux syscall numbers + the inline-asm wrappers.
// amd64 uses `syscall`/rax; aarch64 uses `svc #0`/x8. The numbers differ.
#if defined(__x86_64__)
#define SYS_EXIT_GROUP 231
#define SYS_FUTEX      202
#define SYS_NANOSLEEP   35
#elif defined(__aarch64__)
#define SYS_EXIT_GROUP  94
#define SYS_FUTEX       98
#define SYS_NANOSLEEP  101
#else
#error "unsupported arch"
#endif

// ---------------------------------------------------------------------
// Allocator: size-classed freelist over mmap-backed arena chunks.
// ---------------------------------------------------------------------
//
// Replaces the original 16 MB BSS bump. Each allocation is rounded up
// to a power-of-two size class (16, 32, 64, ..., 32 KiB). Each class
// has its own freelist; freed blocks push onto the head, allocations
// pop from the head. When a class is empty, we bump a slab from the
// current arena chunk (currently 1 MiB); when the chunk runs out, we
// mmap a fresh one. Allocations larger than the biggest size class go
// straight to mmap, and are also returned to the OS on free.
//
// Layout: every block is `[block_hdr_t (16B)] [user payload]`. The
// user pointer is 16 B past the header start, which keeps any natural
// alignment up to 16-byte. The header records the size class (or -1
// for "huge / mmap-direct"); on free it also stores the freelist next
// pointer in the same field that held the size.
//
// Thread safety: a single global mutex `alloc_lock`. Cheap enough for
// v0.7; size-class-per-bucket locks are a future optimization.
//
// volt_alloc still zero-fills the user payload — callers used to rely
// on BSS zeroing the bump region; the freelist reuses memory, so the
// zero contract must be honored explicitly.

#define ARENA_CHUNK_SIZE  (1 * 1024 * 1024) // 1 MiB per arena chunk
#define BLOCK_HDR_SIZE    16                // sizeof(block_hdr_t) padded to 16-byte alignment
#define NUM_SIZE_CLASSES  12                // 16 ... 32768

static const i64 size_class_bytes[NUM_SIZE_CLASSES] = {
    16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768,
};

typedef struct block_hdr {
    // When allocated: holds the size-class index (or -1 for huge).
    // When freed and on a freelist: holds the next-block pointer reinterpret-cast as i64.
    i64 tag;
    // For huge (mmap-direct) blocks, store the mmap size here so free can munmap.
    i64 huge_size;
} block_hdr_t;

// Forward declarations — the futex-based mutex implementation lives below
// (it's used internally by the allocator's global lock).
typedef struct { i32 state; } mutex_t;
static void mutex_lock(mutex_t* m);
static void mutex_unlock(mutex_t* m);
static void volt_byte_copy(char* dst, const char* src, i64 n);

static mutex_t       alloc_lock     = {0};
static block_hdr_t*  freelists[NUM_SIZE_CLASSES] = {0};
static char*         arena_curr     = 0;
static char*         arena_end      = 0;

// Memory-syscall syscall numbers (already declared above for FUTEX/EXIT_GROUP;
// these are the alloc-time ones).
#if defined(__x86_64__)
#define SYS_MMAP   9
#define SYS_MUNMAP 11
#elif defined(__aarch64__)
#define SYS_MMAP   222
#define SYS_MUNMAP 215
#endif

static void volt_die(void) {
#if defined(__x86_64__)
    register i64 rax __asm__("rax") = SYS_EXIT_GROUP;
    register i64 rdi __asm__("rdi") = 1;
    __asm__ volatile("syscall" : : "r"(rax), "r"(rdi) : "rcx", "r11", "memory");
#elif defined(__aarch64__)
    register i64 x8 __asm__("x8") = SYS_EXIT_GROUP;
    register i64 x0 __asm__("x0") = 1;
    __asm__ volatile("svc #0" : : "r"(x8), "r"(x0) : "memory");
#endif
    __builtin_unreachable();
}

static void* volt_mmap_anon(i64 size) {
#if defined(__x86_64__)
    register i64 rax __asm__("rax") = SYS_MMAP;
    register i64 rdi __asm__("rdi") = 0;       // addr NULL
    register i64 rsi __asm__("rsi") = size;
    register i64 rdx __asm__("rdx") = 3;       // PROT_READ | PROT_WRITE
    register i64 r10 __asm__("r10") = 0x22;    // MAP_PRIVATE | MAP_ANONYMOUS
    register i64 r8  __asm__("r8")  = -1;
    register i64 r9  __asm__("r9")  = 0;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10), "r"(r8), "r"(r9)
        : "rcx", "r11", "memory");
    if ((u64)rax > (u64)-4096) return (void*)0;
    return (void*)rax;
#elif defined(__aarch64__)
    register i64 x0 __asm__("x0") = 0;
    register i64 x1 __asm__("x1") = size;
    register i64 x2 __asm__("x2") = 3;
    register i64 x3 __asm__("x3") = 0x22;
    register i64 x4 __asm__("x4") = -1;
    register i64 x5 __asm__("x5") = 0;
    register i64 x8 __asm__("x8") = SYS_MMAP;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5), "r"(x8)
        : "memory");
    if ((u64)x0 > (u64)-4096) return (void*)0;
    return (void*)x0;
#endif
}

static void volt_munmap(void* p, i64 size) {
#if defined(__x86_64__)
    register i64 rax __asm__("rax") = SYS_MUNMAP;
    register i64 rdi __asm__("rdi") = (i64)p;
    register i64 rsi __asm__("rsi") = size;
    __asm__ volatile("syscall" : "+r"(rax) : "r"(rdi), "r"(rsi) : "rcx", "r11", "memory");
#elif defined(__aarch64__)
    register i64 x0 __asm__("x0") = (i64)p;
    register i64 x1 __asm__("x1") = size;
    register i64 x8 __asm__("x8") = SYS_MUNMAP;
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x1), "r"(x8) : "memory");
#endif
}

// Find the smallest size class that fits `size`. Returns -1 if larger
// than the biggest class (caller routes to mmap-direct path).
static i32 find_size_class(i64 size) {
    for (i32 i = 0; i < NUM_SIZE_CLASSES; i++) {
        if (size_class_bytes[i] >= size) return i;
    }
    return -1;
}

static void zero_bytes(void* p, i64 n) {
    char* b = (char*)p;
    for (i64 i = 0; i < n; i++) b[i] = 0;
}

void* volt_alloc(i64 size) {
    if (size <= 0) return (void*)0;
    i32 sc = find_size_class(size);

    // Must be declared before any goto / asm so the prelude — including the
    // mutex_lock — runs first.
    void* result;

    mutex_lock(&alloc_lock);

    if (sc < 0) {
        // Huge: mmap-direct. Round to page (4 KiB) so munmap takes it back.
        i64 total = (BLOCK_HDR_SIZE + size + 4095) & ~4095;
        block_hdr_t* hdr = (block_hdr_t*)volt_mmap_anon(total);
        if (!hdr) {
            mutex_unlock(&alloc_lock);
            volt_die();
        }
        hdr->tag = -1;
        hdr->huge_size = total;
        result = (char*)hdr + BLOCK_HDR_SIZE;
    } else if (freelists[sc]) {
        block_hdr_t* hdr = freelists[sc];
        freelists[sc] = (block_hdr_t*)hdr->tag;  // next link was stashed in tag
        hdr->tag = sc;                             // restore tag for free()
        hdr->huge_size = 0;
        result = (char*)hdr + BLOCK_HDR_SIZE;
    } else {
        // Bump from current arena chunk.
        i64 block_size = BLOCK_HDR_SIZE + size_class_bytes[sc];
        if (arena_curr + block_size > arena_end) {
            i64 chunk = ARENA_CHUNK_SIZE;
            if (block_size > chunk) chunk = (block_size + 4095) & ~4095;
            char* base = (char*)volt_mmap_anon(chunk);
            if (!base) {
                mutex_unlock(&alloc_lock);
                volt_die();
            }
            arena_curr = base;
            arena_end  = base + chunk;
        }
        block_hdr_t* hdr = (block_hdr_t*)arena_curr;
        hdr->tag       = sc;
        hdr->huge_size = 0;
        arena_curr    += block_size;
        result         = (char*)hdr + BLOCK_HDR_SIZE;
    }

    mutex_unlock(&alloc_lock);

    // Zero the user payload — callers expect fresh-allocated bytes to be
    // zero (the old bump relied on BSS zeroing; the freelist reuses memory).
    zero_bytes(result, size);
    return result;
}

// volt_free returns a block to its size-class freelist, or munmaps it
// if it was a huge alloc. Passing 0 is a no-op (Go-style).
void volt_free(void* ptr) {
    if (!ptr) return;
    block_hdr_t* hdr = (block_hdr_t*)((char*)ptr - BLOCK_HDR_SIZE);
    i64 tag = hdr->tag;

    mutex_lock(&alloc_lock);
    if (tag < 0) {
        i64 huge = hdr->huge_size;
        mutex_unlock(&alloc_lock);
        volt_munmap(hdr, huge);
        return;
    }
    i32 sc = (i32)tag;
    // Stash the next-link in tag (overwrites the size class — we'll
    // restore it in volt_alloc when this block is popped).
    hdr->tag = (i64)freelists[sc];
    freelists[sc] = hdr;
    mutex_unlock(&alloc_lock);
}

// ---------------------------------------------------------------------
// futex-based mutex + condvar
// ---------------------------------------------------------------------

#define FUTEX_WAIT 0
#define FUTEX_WAKE 1

static i64 sys_futex(i32* uaddr, i32 op, i32 val) {
#if defined(__x86_64__)
    register i64 rax __asm__("rax") = SYS_FUTEX;
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
#elif defined(__aarch64__)
    register i64 x8 __asm__("x8") = SYS_FUTEX;
    register i64 x0 __asm__("x0") = (i64)uaddr;
    register i64 x1 __asm__("x1") = op;
    register i64 x2 __asm__("x2") = val;
    register i64 x3 __asm__("x3") = 0;
    register i64 x4 __asm__("x4") = 0;
    register i64 x5 __asm__("x5") = 0;
    __asm__ volatile(
        "svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5)
        : "memory");
    return x0;
#endif
}

// (mutex_t was forward-declared in the allocator section above.)
typedef struct { i32 seq; } cond_t;

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

static void cond_broadcast(cond_t* c) {
    __atomic_add_fetch(&c->seq, 1, __ATOMIC_RELEASE);
    sys_futex(&c->seq, FUTEX_WAKE, 0x7fffffff);
}

// ---------------------------------------------------------------------
// Blocking channel (single element type = i64)
// ---------------------------------------------------------------------

typedef struct {
    mutex_t  lock;
    cond_t   not_full;
    cond_t   not_empty;
    i64      cap;          // user-facing capacity: 0 = unbuffered (rendezvous)
    i64      len;
    i64      head;
    i64      tail;
    i64      closed;
    i64*     buf;          // always at least 1 slot — used as the rendezvous slot when cap == 0
    // Unbuffered-only state (cap == 0). `has_handoff` is set by a
    // sender after writing into buf[0]; cleared by the receiver after
    // reading. `receivers_parked` is the count of receivers blocked
    // on not_empty — used so volt_chan_try_send can synchronously
    // hand off when a partner is already waiting (for select).
    i64      has_handoff;
    i64      receivers_parked;
} chan_i64_t;

void* volt_chan_new(i64 cap) {
    if (cap < 0) cap = 0;
    chan_i64_t* c = (chan_i64_t*)volt_alloc((i64)sizeof(chan_i64_t));
    c->lock.state    = 0;
    c->not_full.seq  = 0;
    c->not_empty.seq = 0;
    c->cap    = cap;
    c->len    = 0;
    c->head   = 0;
    c->tail   = 0;
    c->closed = 0;
    c->has_handoff = 0;
    c->receivers_parked = 0;
    // Always alloc at least 1 slot — for cap == 0, buf[0] is the
    // rendezvous handoff slot; for cap > 0, it's the ring buffer.
    i64 slots = cap;
    if (slots == 0) slots = 1;
    c->buf = (i64*)volt_alloc(slots * (i64)sizeof(i64));
    return (void*)c;
}

void volt_chan_send(void* ch_, i64 v) {
    chan_i64_t* c = (chan_i64_t*)ch_;
    mutex_lock(&c->lock);
    if (c->cap == 0) {
        // Unbuffered: wait until any previous handoff has been picked
        // up, then publish the value and wait until THIS one has
        // been picked up. True rendezvous.
        while (c->has_handoff && !c->closed) {
            cond_wait(&c->not_full, &c->lock);
        }
        if (c->closed) {
            mutex_unlock(&c->lock);
            volt_die();
        }
        c->buf[0] = v;
        c->has_handoff = 1;
        cond_signal(&c->not_empty);
        while (c->has_handoff && !c->closed) {
            cond_wait(&c->not_full, &c->lock);
        }
        mutex_unlock(&c->lock);
        return;
    }
    while (c->len >= c->cap && !c->closed) {
        cond_wait(&c->not_full, &c->lock);
    }
    if (c->closed) {
        mutex_unlock(&c->lock);
        volt_die(); // send on closed channel — panic (Go-style)
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
    if (c->cap == 0) {
        c->receivers_parked++;
        while (!c->has_handoff && !c->closed) {
            cond_wait(&c->not_empty, &c->lock);
        }
        c->receivers_parked--;
        if (!c->has_handoff && c->closed) {
            mutex_unlock(&c->lock);
            return 0;
        }
        i64 v = c->buf[0];
        c->has_handoff = 0;
        cond_signal(&c->not_full); // wake the sender (and any try_send waiters)
        mutex_unlock(&c->lock);
        return v;
    }
    while (c->len == 0 && !c->closed) {
        cond_wait(&c->not_empty, &c->lock);
    }
    if (c->len == 0 && c->closed) {
        mutex_unlock(&c->lock);
        return 0;
    }
    i64 v = c->buf[c->head];
    c->head = (c->head + 1) % c->cap;
    c->len--;
    cond_signal(&c->not_full);
    mutex_unlock(&c->lock);
    return v;
}

// Two-value form: returns {value, ok}. `ok` is 0 if the channel was
// closed AND empty when we tried to receive; 1 otherwise.
typedef struct { i64 v; i64 ok; } chan_recv2_t;

chan_recv2_t volt_chan_recv2(void* ch_) {
    chan_i64_t* c = (chan_i64_t*)ch_;
    chan_recv2_t r;
    mutex_lock(&c->lock);
    if (c->cap == 0) {
        c->receivers_parked++;
        while (!c->has_handoff && !c->closed) {
            cond_wait(&c->not_empty, &c->lock);
        }
        c->receivers_parked--;
        if (!c->has_handoff && c->closed) {
            mutex_unlock(&c->lock);
            r.v = 0;
            r.ok = 0;
            return r;
        }
        r.v = c->buf[0];
        c->has_handoff = 0;
        cond_signal(&c->not_full);
        mutex_unlock(&c->lock);
        r.ok = 1;
        return r;
    }
    while (c->len == 0 && !c->closed) {
        cond_wait(&c->not_empty, &c->lock);
    }
    if (c->len == 0 && c->closed) {
        mutex_unlock(&c->lock);
        r.v = 0;
        r.ok = 0;
        return r;
    }
    r.v = c->buf[c->head];
    c->head = (c->head + 1) % c->cap;
    c->len--;
    cond_signal(&c->not_full);
    mutex_unlock(&c->lock);
    r.ok = 1;
    return r;
}

void volt_chan_close(void* ch_) {
    chan_i64_t* c = (chan_i64_t*)ch_;
    mutex_lock(&c->lock);
    c->closed = 1;
    cond_broadcast(&c->not_empty);
    cond_broadcast(&c->not_full);
    mutex_unlock(&c->lock);
}

// Non-blocking send. Returns 1 if value was queued, 0 if the channel
// is full. Panics if the channel is already closed (Go semantics).
// On a cap=0 channel: succeeds only if a receiver is currently parked
// — the value hands off synchronously to that receiver.
i64 volt_chan_try_send(void* ch_, i64 v) {
    chan_i64_t* c = (chan_i64_t*)ch_;
    mutex_lock(&c->lock);
    if (c->closed) {
        mutex_unlock(&c->lock);
        volt_die();
    }
    if (c->cap == 0) {
        if (c->has_handoff || c->receivers_parked == 0) {
            mutex_unlock(&c->lock);
            return 0;
        }
        c->buf[0] = v;
        c->has_handoff = 1;
        cond_signal(&c->not_empty);
        mutex_unlock(&c->lock);
        return 1;
    }
    if (c->len >= c->cap) {
        mutex_unlock(&c->lock);
        return 0;
    }
    c->buf[c->tail] = v;
    c->tail = (c->tail + 1) % c->cap;
    c->len++;
    cond_signal(&c->not_empty);
    mutex_unlock(&c->lock);
    return 1;
}

// Non-blocking recv. Returns {value, ok}: ok=1 on success, ok=0 if
// the channel is empty AND open, ok=0 with value=0 if closed+empty.
// On a cap=0 channel: succeeds only if a sender's handoff is pending.
chan_recv2_t volt_chan_try_recv(void* ch_) {
    chan_i64_t* c = (chan_i64_t*)ch_;
    chan_recv2_t r;
    mutex_lock(&c->lock);
    if (c->cap == 0) {
        if (!c->has_handoff) {
            mutex_unlock(&c->lock);
            r.v = 0;
            r.ok = 0;
            return r;
        }
        r.v = c->buf[0];
        c->has_handoff = 0;
        cond_signal(&c->not_full);
        mutex_unlock(&c->lock);
        r.ok = 1;
        return r;
    }
    if (c->len == 0) {
        mutex_unlock(&c->lock);
        r.v = 0;
        r.ok = 0;
        return r;
    }
    r.v = c->buf[c->head];
    c->head = (c->head + 1) % c->cap;
    c->len--;
    cond_signal(&c->not_full);
    mutex_unlock(&c->lock);
    r.ok = 1;
    return r;
}

// Sleep for `ns` nanoseconds via the sys_nanosleep syscall.
void volt_sleep(i64 ns) {
    if (ns <= 0) return;
    struct { i64 sec; i64 nsec; } req;
    req.sec  = ns / 1000000000;
    req.nsec = ns % 1000000000;
#if defined(__x86_64__)
    register i64 rax __asm__("rax") = SYS_NANOSLEEP;
    register i64 rdi __asm__("rdi") = (i64)&req;
    register i64 rsi __asm__("rsi") = 0;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi)
        : "rcx", "r11", "memory");
#elif defined(__aarch64__)
    register i64 x8 __asm__("x8") = SYS_NANOSLEEP;
    register i64 x0 __asm__("x0") = (i64)&req;
    register i64 x1 __asm__("x1") = 0;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1)
        : "memory");
#endif
}

// Brief yield — used by select to avoid 100% CPU when no case is ready.
// nanosleep(0, 1ms).
void volt_yield(void) {
    struct { i64 sec; i64 nsec; } req;
    req.sec = 0;
    req.nsec = 1000000; // 1 ms
#if defined(__x86_64__)
    register i64 rax __asm__("rax") = SYS_NANOSLEEP;
    register i64 rdi __asm__("rdi") = (i64)&req;
    register i64 rsi __asm__("rsi") = 0;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi)
        : "rcx", "r11", "memory");
#elif defined(__aarch64__)
    register i64 x8 __asm__("x8") = SYS_NANOSLEEP;
    register i64 x0 __asm__("x0") = (i64)&req;
    register i64 x1 __asm__("x1") = 0;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1)
        : "memory");
#endif
}

// ---------------------------------------------------------------------
// Map (string → i64). Chained hash table, fixed bucket count.
// Keys are passed as (ptr, len) pairs (the same {ptr, i64} the volt
// `%string` layout uses). Values are i64. Concurrent access is guarded
// by a per-map mutex so map ops are thread-safe.
// ---------------------------------------------------------------------

// Map: chaining hash table with load-factor-based resize. Buckets are
// allocated dynamically (not a fixed array); when count exceeds
// 0.75 * num_buckets we double `num_buckets` and rehash everything
// under the existing lock. The new bucket array is volt_alloc'd
// fresh; the old one is intentionally leaked for now (auto-free hooks
// into Drop are A3 territory).

#define MAP_INIT_BUCKETS 16  // small initial table — grows as needed

typedef struct map_entry {
    struct map_entry* next;
    char*             key_ptr;
    i64               key_len;
    i64               value;
} map_entry_t;

typedef struct {
    mutex_t       lock;
    i64           count;
    i64           num_buckets;
    map_entry_t** buckets; // length == num_buckets
} map_t;

static u64 hash_bytes(const char* p, i64 n) {
    u64 h = 5381;
    for (i64 i = 0; i < n; i++) {
        h = ((h << 5) + h) + (u64)(unsigned char)p[i]; // djb2
    }
    return h;
}

static int key_eq(const char* a, i64 alen, const char* b, i64 blen) {
    if (alen != blen) return 0;
    for (i64 i = 0; i < alen; i++) {
        if (a[i] != b[i]) return 0;
    }
    return 1;
}

void* volt_map_new(void) {
    map_t* m = (map_t*)volt_alloc((i64)sizeof(map_t));
    m->num_buckets = MAP_INIT_BUCKETS;
    m->buckets = (map_entry_t**)volt_alloc((i64)sizeof(map_entry_t*) * MAP_INIT_BUCKETS);
    return m;
}

// map_maybe_grow doubles the bucket array and rehashes every entry
// into its new slot. Called from volt_map_set under the map's lock.
static void map_maybe_grow(map_t* m) {
    // Resize when load factor exceeds 0.75 (count > num_buckets * 3 / 4).
    if (m->count * 4 <= m->num_buckets * 3) return;

    i64 new_n = m->num_buckets * 2;
    map_entry_t** new_buckets = (map_entry_t**)volt_alloc((i64)sizeof(map_entry_t*) * new_n);
    for (i64 i = 0; i < m->num_buckets; i++) {
        map_entry_t* e = m->buckets[i];
        while (e) {
            map_entry_t* next = e->next;
            u64 h = hash_bytes(e->key_ptr, e->key_len);
            i64 idx = (i64)(h % (u64)new_n);
            e->next = new_buckets[idx];
            new_buckets[idx] = e;
            e = next;
        }
    }
    m->buckets = new_buckets;
    m->num_buckets = new_n;
}

i64 volt_map_get(void* m_, char* key_ptr, i64 key_len) {
    map_t* m = (map_t*)m_;
    if (m == 0) return 0;
    mutex_lock(&m->lock);
    u64 h = hash_bytes(key_ptr, key_len);
    map_entry_t* e = m->buckets[h % (u64)m->num_buckets];
    while (e) {
        if (key_eq(e->key_ptr, e->key_len, key_ptr, key_len)) {
            i64 v = e->value;
            mutex_unlock(&m->lock);
            return v;
        }
        e = e->next;
    }
    mutex_unlock(&m->lock);
    return 0; // not found: zero value (Go-like)
}

void volt_map_set(void* m_, char* key_ptr, i64 key_len, i64 value) {
    map_t* m = (map_t*)m_;
    mutex_lock(&m->lock);
    u64 h = hash_bytes(key_ptr, key_len);
    map_entry_t** bucket = &m->buckets[h % (u64)m->num_buckets];
    map_entry_t* e = *bucket;
    while (e) {
        if (key_eq(e->key_ptr, e->key_len, key_ptr, key_len)) {
            e->value = value;
            mutex_unlock(&m->lock);
            return;
        }
        e = e->next;
    }
    map_entry_t* ne = (map_entry_t*)volt_alloc((i64)sizeof(map_entry_t));
    ne->next    = *bucket;
    ne->key_ptr = key_ptr;
    ne->key_len = key_len;
    ne->value   = value;
    *bucket = ne;
    m->count++;
    map_maybe_grow(m);
    mutex_unlock(&m->lock);
}

// ---- slice grow / append --------------------------------------------
// volt_slice_grow appends one element (whose bytes are at *new_elem)
// to a slice whose header lives in *s_io. If len < cap, the element
// is written in place at offset len*elem_size and len is incremented.
// Otherwise a fresh buffer of size max(8, cap*2) is mmap'd via
// volt_alloc, the existing elements are copied over, and the slice
// header is updated to point at the new buffer.
//
// Memory layout mirrors the LLVM %slice = { ptr, i64 len, i64 cap }.

typedef struct { void* ptr; i64 len; i64 cap; } slice_io_t;

void volt_slice_grow(void* s_io, i64 elem_size, void* new_elem) {
    slice_io_t* s = (slice_io_t*)s_io;
    if (s->len >= s->cap) {
        i64 new_cap = s->cap * 2;
        if (new_cap < 8) new_cap = 8;
        char* new_buf = (char*)volt_alloc(new_cap * elem_size);
        if (s->len > 0 && s->ptr != 0) {
            volt_byte_copy(new_buf, (const char*)s->ptr, s->len * elem_size);
        }
        s->ptr = new_buf;
        s->cap = new_cap;
    }
    char* dst = (char*)s->ptr + s->len * elem_size;
    volt_byte_copy(dst, (const char*)new_elem, elem_size);
    s->len++;
}

// volt_map_clone allocates a fresh map and copies every entry from
// `src`. Shallow: key bytes are reused (interned by the runtime
// already) and values are copied as opaque i64s. Pointer-valued maps
// will share whatever the values point at.
void* volt_map_clone(void* src_) {
    if (src_ == 0) return (void*)0;
    map_t* src = (map_t*)src_;
    map_t* dst = (map_t*)volt_alloc((i64)sizeof(map_t));
    mutex_lock(&src->lock);
    dst->num_buckets = src->num_buckets;
    dst->buckets = (map_entry_t**)volt_alloc((i64)sizeof(map_entry_t*) * dst->num_buckets);
    for (i64 i = 0; i < src->num_buckets; i++) {
        for (map_entry_t* e = src->buckets[i]; e != 0; e = e->next) {
            map_entry_t* ne = (map_entry_t*)volt_alloc((i64)sizeof(map_entry_t));
            ne->next    = dst->buckets[i];
            ne->key_ptr = e->key_ptr;
            ne->key_len = e->key_len;
            ne->value   = e->value;
            dst->buckets[i] = ne;
            dst->count++;
        }
    }
    mutex_unlock(&src->lock);
    return dst;
}

i64 volt_map_len(void* m_) {
    if (m_ == 0) return 0;
    return ((map_t*)m_)->count;
}

// ---------------------------------------------------------------------
// Formatted writers — used by log.Println intrinsic.
// volt_write is provided by start_amd64.s / start_arm64.s.
// ---------------------------------------------------------------------

extern void volt_write(i64 fd, const char* buf, i64 len);

// volt_write_int writes the base-10 representation of `n` to `fd`.
void volt_write_int(i64 fd, i64 n) {
    char tmp[24];           // up to 20 digits for i64, plus sign + slack
    i64 tlen = 0;
    i64 neg = (n < 0);
    u64 u = neg ? (u64)(-n) : (u64)n;
    if (u == 0) {
        tmp[tlen++] = '0';
    } else {
        while (u > 0) {
            tmp[tlen++] = (char)('0' + (u % 10));
            u /= 10;
        }
    }
    char buf[24];
    i64 len = 0;
    if (neg) buf[len++] = '-';
    while (tlen > 0) {
        buf[len++] = tmp[--tlen];
    }
    volt_write(fd, buf, len);
}

// volt_write_bool writes "true" or "false" to `fd`.
void volt_write_bool(i64 fd, i64 b) {
    if (b) {
        volt_write(fd, "true", 4);
    } else {
        volt_write(fd, "false", 5);
    }
}

// volt_buf_clone returns a fresh heap buffer containing the first `n`
// bytes of `src`. Used by the clone() built-in for deep-copying the
// backing bytes of strings (and, in future, slices).
char* volt_buf_clone(const char* src, i64 n) {
    if (n <= 0) return (char*)0;
    char* out = (char*)volt_alloc(n);
    for (i64 i = 0; i < n; i++) {
        out[i] = src[i];
    }
    return out;
}

// ---------------------------------------------------------------------
// User-facing sync primitives: atomic, mutex, rwmutex (all word-sized)
// ---------------------------------------------------------------------
// Each is a heap-allocated struct holding the wrapped i64 value plus
// any lock state. User code holds an opaque ptr handle; copying the
// handle gives another reference to the same wrapper (reference-typed,
// like channels).
//
// Inner type T is currently fixed to i64 (covers int, byte, bool, ptr —
// all promoted to i64 at the IR boundary). Struct wrapping needs a
// guard-with-Drop story; see TODO.md.

// ---- atomic int -----------------------------------------------------

typedef struct { i64 value; } atomic_t;

void* volt_atomic_new(i64 initial) {
    atomic_t* a = (atomic_t*)volt_alloc((i64)sizeof(atomic_t));
    a->value = initial;
    return a;
}

i64 volt_atomic_load(void* a_) {
    atomic_t* a = (atomic_t*)a_;
    return __atomic_load_n(&a->value, __ATOMIC_SEQ_CST);
}

void volt_atomic_store(void* a_, i64 v) {
    atomic_t* a = (atomic_t*)a_;
    __atomic_store_n(&a->value, v, __ATOMIC_SEQ_CST);
}

// volt_atomic_add returns the NEW value after the addition.
i64 volt_atomic_add(void* a_, i64 delta) {
    atomic_t* a = (atomic_t*)a_;
    return __atomic_add_fetch(&a->value, delta, __ATOMIC_SEQ_CST);
}

// volt_atomic_cas returns 1 if the swap happened, 0 otherwise.
i64 volt_atomic_cas(void* a_, i64 old_val, i64 new_val) {
    atomic_t* a = (atomic_t*)a_;
    i64 expected = old_val;
    if (__atomic_compare_exchange_n(&a->value, &expected, new_val, 0,
            __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)) {
        return 1;
    }
    return 0;
}

// ---- atomic int32 ---------------------------------------------------

typedef struct { i32 value; } atomic_i32_t;

void* volt_atomic_new_i32(i32 initial) {
    atomic_i32_t* a = (atomic_i32_t*)volt_alloc((i64)sizeof(atomic_i32_t));
    a->value = initial;
    return a;
}

i32 volt_atomic_load_i32(void* a_) {
    return __atomic_load_n(&((atomic_i32_t*)a_)->value, __ATOMIC_SEQ_CST);
}

void volt_atomic_store_i32(void* a_, i32 v) {
    __atomic_store_n(&((atomic_i32_t*)a_)->value, v, __ATOMIC_SEQ_CST);
}

i32 volt_atomic_add_i32(void* a_, i32 delta) {
    return __atomic_add_fetch(&((atomic_i32_t*)a_)->value, delta, __ATOMIC_SEQ_CST);
}

i64 volt_atomic_cas_i32(void* a_, i32 old_val, i32 new_val) {
    i32 expected = old_val;
    if (__atomic_compare_exchange_n(&((atomic_i32_t*)a_)->value, &expected, new_val, 0,
            __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)) {
        return 1;
    }
    return 0;
}

// ---- atomic int16 ---------------------------------------------------

typedef struct { i16 value; } atomic_i16_t;

void* volt_atomic_new_i16(i16 initial) {
    atomic_i16_t* a = (atomic_i16_t*)volt_alloc((i64)sizeof(atomic_i16_t));
    a->value = initial;
    return a;
}

i16 volt_atomic_load_i16(void* a_) {
    return __atomic_load_n(&((atomic_i16_t*)a_)->value, __ATOMIC_SEQ_CST);
}

void volt_atomic_store_i16(void* a_, i16 v) {
    __atomic_store_n(&((atomic_i16_t*)a_)->value, v, __ATOMIC_SEQ_CST);
}

i16 volt_atomic_add_i16(void* a_, i16 delta) {
    return __atomic_add_fetch(&((atomic_i16_t*)a_)->value, delta, __ATOMIC_SEQ_CST);
}

i64 volt_atomic_cas_i16(void* a_, i16 old_val, i16 new_val) {
    i16 expected = old_val;
    if (__atomic_compare_exchange_n(&((atomic_i16_t*)a_)->value, &expected, new_val, 0,
            __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)) {
        return 1;
    }
    return 0;
}

// ---- atomic int8 / byte ---------------------------------------------

typedef struct { i8 value; } atomic_i8_t;

void* volt_atomic_new_i8(i8 initial) {
    atomic_i8_t* a = (atomic_i8_t*)volt_alloc((i64)sizeof(atomic_i8_t));
    a->value = initial;
    return a;
}

i8 volt_atomic_load_i8(void* a_) {
    return __atomic_load_n(&((atomic_i8_t*)a_)->value, __ATOMIC_SEQ_CST);
}

void volt_atomic_store_i8(void* a_, i8 v) {
    __atomic_store_n(&((atomic_i8_t*)a_)->value, v, __ATOMIC_SEQ_CST);
}

i8 volt_atomic_add_i8(void* a_, i8 delta) {
    return __atomic_add_fetch(&((atomic_i8_t*)a_)->value, delta, __ATOMIC_SEQ_CST);
}

i64 volt_atomic_cas_i8(void* a_, i8 old_val, i8 new_val) {
    i8 expected = old_val;
    if (__atomic_compare_exchange_n(&((atomic_i8_t*)a_)->value, &expected, new_val, 0,
            __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)) {
        return 1;
    }
    return 0;
}

// ---- atomic bool ----------------------------------------------------
// Carried over the ABI as i8 (0=false, 1=true). Add isn't defined.

typedef struct { i8 value; } atomic_bool_t;

void* volt_atomic_new_bool(i8 initial) {
    atomic_bool_t* a = (atomic_bool_t*)volt_alloc((i64)sizeof(atomic_bool_t));
    a->value = initial ? 1 : 0;
    return a;
}

i8 volt_atomic_load_bool(void* a_) {
    return __atomic_load_n(&((atomic_bool_t*)a_)->value, __ATOMIC_SEQ_CST);
}

void volt_atomic_store_bool(void* a_, i8 v) {
    __atomic_store_n(&((atomic_bool_t*)a_)->value, v ? 1 : 0, __ATOMIC_SEQ_CST);
}

i64 volt_atomic_cas_bool(void* a_, i8 old_val, i8 new_val) {
    i8 expected = old_val ? 1 : 0;
    i8 desired = new_val ? 1 : 0;
    if (__atomic_compare_exchange_n(&((atomic_bool_t*)a_)->value, &expected, desired, 0,
            __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)) {
        return 1;
    }
    return 0;
}

// ---- atomic ptr -----------------------------------------------------
// Lock-free pointer (handle for hand-rolled lock-free data structures).
// Load / Store / CAS only — addition isn't well-defined for pointers.

typedef struct { void* value; } atomic_ptr_t;

void* volt_atomic_new_ptr(void* initial) {
    atomic_ptr_t* a = (atomic_ptr_t*)volt_alloc((i64)sizeof(atomic_ptr_t));
    a->value = initial;
    return a;
}

void* volt_atomic_load_ptr(void* a_) {
    return __atomic_load_n(&((atomic_ptr_t*)a_)->value, __ATOMIC_SEQ_CST);
}

void volt_atomic_store_ptr(void* a_, void* v) {
    __atomic_store_n(&((atomic_ptr_t*)a_)->value, v, __ATOMIC_SEQ_CST);
}

i64 volt_atomic_cas_ptr(void* a_, void* old_val, void* new_val) {
    void* expected = old_val;
    if (__atomic_compare_exchange_n(&((atomic_ptr_t*)a_)->value, &expected, new_val, 0,
            __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)) {
        return 1;
    }
    return 0;
}

// ---- mutex T --------------------------------------------------------
// The mutex wraps an arbitrary T inline. Layout is
//   { mutex_t lock; <payload bytes...> }
// with the payload starting at offset sizeof(sync_mutex_t). The compiler
// passes the payload size at construction and copies the initial bytes
// in. volt_mutex_lock returns a pointer to the payload so the caller
// can read/write fields directly while the lock is held.

typedef struct {
    mutex_t lock;
    // payload[] follows inline — size set by the caller via volt_mutex_new
} sync_mutex_t;

static void volt_byte_copy(char* dst, const char* src, i64 n) {
    for (i64 i = 0; i < n; i++) dst[i] = src[i];
}

void* volt_mutex_new(i64 payload_size, void* initial) {
    if (payload_size < 0) payload_size = 0;
    sync_mutex_t* m = (sync_mutex_t*)volt_alloc((i64)sizeof(sync_mutex_t) + payload_size);
    m->lock.state = 0;
    if (initial && payload_size > 0) {
        volt_byte_copy((char*)m + sizeof(sync_mutex_t), (const char*)initial, payload_size);
    }
    return m;
}

// volt_mutex_lock acquires the lock and returns a pointer to the
// inline payload. The pointer is only valid until volt_mutex_unlock.
void* volt_mutex_lock(void* m_) {
    sync_mutex_t* m = (sync_mutex_t*)m_;
    mutex_lock(&m->lock);
    return (char*)m + sizeof(sync_mutex_t);
}

void volt_mutex_unlock(void* m_) {
    sync_mutex_t* m = (sync_mutex_t*)m_;
    mutex_unlock(&m->lock);
}

// ---- rwmutex T ------------------------------------------------------
// Reader/writer lock. Many concurrent readers OR one exclusive writer.
// Implementation: a single mutex_t serializes ALL state transitions
// (counter updates, sleep/wake). Readers can hold the rwlock while
// the inner mutex_t is free.
//
// Layout: { mutex_t lock; cond_t free_cond; i32 readers; i32 writer;
//           <payload bytes...> } with the payload starting at offset
// sizeof(sync_rwmutex_t). Lock/LockRead return a pointer to the payload;
// Unlock/UnlockRead release.

typedef struct {
    mutex_t lock;       // protects counters + serializes wakeups
    cond_t  free_cond;  // waiters wake when readers==0 and writer==0
    i32     readers;    // active readers
    i32     writer;     // 0 = no writer, 1 = a writer holds it
    // payload[] follows inline — size set by the caller via volt_rwmutex_new
} sync_rwmutex_t;

void* volt_rwmutex_new(i64 payload_size, void* initial) {
    if (payload_size < 0) payload_size = 0;
    sync_rwmutex_t* r = (sync_rwmutex_t*)volt_alloc((i64)sizeof(sync_rwmutex_t) + payload_size);
    r->lock.state = 0;
    r->free_cond.seq = 0;
    r->readers = 0;
    r->writer = 0;
    if (initial && payload_size > 0) {
        volt_byte_copy((char*)r + sizeof(sync_rwmutex_t), (const char*)initial, payload_size);
    }
    return r;
}

// volt_rwmutex_lock_read acquires shared (read) access and returns a
// pointer to the inline payload. Pair with volt_rwmutex_unlock_read(r).
void* volt_rwmutex_lock_read(void* r_) {
    sync_rwmutex_t* r = (sync_rwmutex_t*)r_;
    mutex_lock(&r->lock);
    while (r->writer != 0) {
        cond_wait(&r->free_cond, &r->lock);
    }
    r->readers++;
    mutex_unlock(&r->lock);
    return (char*)r + sizeof(sync_rwmutex_t);
}

void volt_rwmutex_unlock_read(void* r_) {
    sync_rwmutex_t* r = (sync_rwmutex_t*)r_;
    mutex_lock(&r->lock);
    r->readers--;
    if (r->readers == 0) {
        cond_broadcast(&r->free_cond);
    }
    mutex_unlock(&r->lock);
}

// volt_rwmutex_lock acquires exclusive (write) access and returns a
// pointer to the inline payload. Pair with volt_rwmutex_unlock(r).
void* volt_rwmutex_lock(void* r_) {
    sync_rwmutex_t* r = (sync_rwmutex_t*)r_;
    mutex_lock(&r->lock);
    while (r->writer != 0 || r->readers != 0) {
        cond_wait(&r->free_cond, &r->lock);
    }
    r->writer = 1;
    mutex_unlock(&r->lock);
    return (char*)r + sizeof(sync_rwmutex_t);
}

void volt_rwmutex_unlock(void* r_) {
    sync_rwmutex_t* r = (sync_rwmutex_t*)r_;
    mutex_lock(&r->lock);
    r->writer = 0;
    cond_broadcast(&r->free_cond);
    mutex_unlock(&r->lock);
}

// ---- waitgroup ------------------------------------------------------
// Counter + cond_var. Add/Done mutate the counter; if it hits zero,
// broadcast wakes every thread blocked in Wait. Add may be called with
// any delta (positive to bump expected workers, negative to drop them).

typedef struct {
    mutex_t lock;
    cond_t  zero_cond;
    i64     counter;
} waitgroup_t;

void* volt_waitgroup_new(i64 initial) {
    waitgroup_t* w = (waitgroup_t*)volt_alloc((i64)sizeof(waitgroup_t));
    w->lock.state = 0;
    w->zero_cond.seq = 0;
    w->counter = initial;
    return w;
}

void volt_waitgroup_add(void* w_, i64 delta) {
    waitgroup_t* w = (waitgroup_t*)w_;
    mutex_lock(&w->lock);
    w->counter += delta;
    if (w->counter == 0) {
        cond_broadcast(&w->zero_cond);
    }
    mutex_unlock(&w->lock);
}

void volt_waitgroup_done(void* w_) {
    volt_waitgroup_add(w_, -1);
}

void volt_waitgroup_wait(void* w_) {
    waitgroup_t* w = (waitgroup_t*)w_;
    mutex_lock(&w->lock);
    while (w->counter != 0) {
        cond_wait(&w->zero_cond, &w->lock);
    }
    mutex_unlock(&w->lock);
}

// ---- once -----------------------------------------------------------
// State machine: NEW (0) -> RUNNING (1) -> DONE (2).
// The single surface op is volt_once_do — every other caller blocks
// in cond_wait until the closure completes; subsequent calls return
// immediately once state == DONE.

typedef struct {
    mutex_t lock;
    cond_t  done_cond;
    i32     state;          // 0 = NEW, 1 = RUNNING, 2 = DONE
    i32     _pad;
} once_t;

void* volt_once_new(void) {
    once_t* o = (once_t*)volt_alloc((i64)sizeof(once_t));
    o->lock.state = 0;
    o->done_cond.seq = 0;
    o->state = 0;
    return o;
}

// volt_once_do is the closure-form once: takes a function pointer and
// its env, runs fn(env) exactly once across all callers, and blocks
// every other caller until that single run completes.
void volt_once_do(void* o_, void* fn_, void* env) {
    once_t* o = (once_t*)o_;
    mutex_lock(&o->lock);
    if (o->state == 0) {
        o->state = 1;
        mutex_unlock(&o->lock);
        // Run the closure outside the lock so other Do callers can
        // queue up on done_cond rather than spin-busy on lock contention.
        ((void (*)(void*))fn_)(env);
        mutex_lock(&o->lock);
        o->state = 2;
        cond_broadcast(&o->done_cond);
        mutex_unlock(&o->lock);
        return;
    }
    while (o->state != 2) {
        cond_wait(&o->done_cond, &o->lock);
    }
    mutex_unlock(&o->lock);
}
