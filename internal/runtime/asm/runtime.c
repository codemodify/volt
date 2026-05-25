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
// Static heap + thread-safe bump allocator
// ---------------------------------------------------------------------

static char volt_heap[16 * 1024 * 1024]; // 16 MB BSS
static u64  volt_heap_pos = 0;

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
    while (c->len == 0 && !c->closed) {
        cond_wait(&c->not_empty, &c->lock);
    }
    if (c->len == 0 && c->closed) {
        // Empty + closed: return zero value (Go-like — drained).
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
i64 volt_chan_try_send(void* ch_, i64 v) {
    chan_i64_t* c = (chan_i64_t*)ch_;
    mutex_lock(&c->lock);
    if (c->closed) {
        mutex_unlock(&c->lock);
        volt_die();
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
// Caller can distinguish "would block" from "closed" via a follow-up
// blocking recv if it cares.
chan_recv2_t volt_chan_try_recv(void* ch_) {
    chan_i64_t* c = (chan_i64_t*)ch_;
    chan_recv2_t r;
    mutex_lock(&c->lock);
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

#define MAP_BUCKETS 256

typedef struct map_entry {
    struct map_entry* next;
    char*             key_ptr;
    i64               key_len;
    i64               value;
} map_entry_t;

typedef struct {
    mutex_t      lock;
    i64          count;
    map_entry_t* buckets[MAP_BUCKETS];
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
    return (void*)volt_alloc((i64)sizeof(map_t));
}

i64 volt_map_get(void* m_, char* key_ptr, i64 key_len) {
    map_t* m = (map_t*)m_;
    if (m == 0) return 0;
    mutex_lock(&m->lock);
    u64 h = hash_bytes(key_ptr, key_len);
    map_entry_t* e = m->buckets[h % MAP_BUCKETS];
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
    map_entry_t** bucket = &m->buckets[h % MAP_BUCKETS];
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
    mutex_unlock(&m->lock);
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
// Begin atomically promotes NEW->RUNNING and returns 1 to that caller;
// any other caller blocks in cond_wait until the state reaches DONE
// (the original caller's Done() call broadcasts). After DONE, Begin
// returns 0 immediately on every subsequent call.

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

i64 volt_once_begin(void* o_) {
    once_t* o = (once_t*)o_;
    mutex_lock(&o->lock);
    if (o->state == 0) {
        o->state = 1;
        mutex_unlock(&o->lock);
        return 1;
    }
    while (o->state != 2) {
        cond_wait(&o->done_cond, &o->lock);
    }
    mutex_unlock(&o->lock);
    return 0;
}

void volt_once_done(void* o_) {
    once_t* o = (once_t*)o_;
    mutex_lock(&o->lock);
    o->state = 2;
    cond_broadcast(&o->done_cond);
    mutex_unlock(&o->lock);
}
