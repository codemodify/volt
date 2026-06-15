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
typedef unsigned char u8;

// Arch-conditional Linux syscall numbers + the inline-asm wrappers.
// amd64 uses `syscall`/rax; aarch64 uses `svc #0`/x8. The numbers differ.
#if defined(__x86_64__)
#define SYS_EXIT_GROUP      231
#define SYS_FUTEX           202
#define SYS_NANOSLEEP        35
#define SYS_OPENAT          257
#define SYS_READ              0
#define SYS_WRITE             1
#define SYS_CLOSE             3
#define SYS_UNLINKAT        263
#define SYS_CLOCK_GETTIME   228
#define SYS_SOCKET           41
#define SYS_CONNECT          42
#define SYS_ACCEPT           43
#define SYS_BIND             49
#define SYS_LISTEN           50
#define SYS_SETSOCKOPT       54
#define SYS_GETRANDOM       318
#define SYS_MKDIRAT         258
#define SYS_FACCESSAT       269
#define SYS_GETTID          186
#define SYS_CLONE            56
#define SYS_EXECVE          59
#define SYS_WAIT4           61
#define SYS_PIPE2          293
#define SYS_DUP3           292
#define SYS_IOCTL            16
#define SYS_PPOLL          271
#define SYS_CHDIR            80
#define SYS_RT_SIGACTION     13
#define SYS_KILL             62
#define SYS_GETPID           39
#define SYS_EXIT            60
#elif defined(__aarch64__)
#define SYS_EXIT_GROUP       94
#define SYS_FUTEX            98
#define SYS_NANOSLEEP       101
#define SYS_OPENAT           56
#define SYS_READ             63
#define SYS_WRITE            64
#define SYS_CLOSE            57
#define SYS_UNLINKAT         35
#define SYS_CLOCK_GETTIME   113
#define SYS_SOCKET          198
#define SYS_CONNECT         203
#define SYS_ACCEPT          202
#define SYS_BIND            200
#define SYS_LISTEN          201
#define SYS_SETSOCKOPT      208
#define SYS_GETRANDOM       278
#define SYS_MKDIRAT          34
#define SYS_FACCESSAT        48
#define SYS_GETTID          178
#define SYS_CLONE           220
#define SYS_EXECVE          221
#define SYS_WAIT4           260
#define SYS_PIPE2            59
#define SYS_DUP3            24
#define SYS_IOCTL            29
#define SYS_PPOLL            73
#define SYS_CHDIR            49
#define SYS_RT_SIGACTION    134
#define SYS_KILL            129
#define SYS_GETPID          172
#define SYS_EXIT            93
#else
#error "unsupported arch"
#endif

// Socket-family / type constants (same on amd64 + arm64 Linux).
#define AF_INET        2
#define SOCK_STREAM    1
#define IPPROTO_TCP    6
#define SOL_SOCKET     1
#define SO_REUSEADDR   2

// CLOCK_REALTIME — wall clock; CLOCK_MONOTONIC — process-monotonic.
#define CLOCK_REALTIME  0
#define CLOCK_MONOTONIC 1

// AT_FDCWD = -100 — passes "current working directory" to openat.
#define AT_FDCWD (-100)

// Open flags (Linux ABI; same numeric values across x86_64 and aarch64).
#define O_RDONLY  0x0000
#define O_WRONLY  0x0001
#define O_RDWR    0x0002
#define O_CREAT   0x0040
#define O_TRUNC   0x0200
#define O_APPEND  0x0400

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
// Tunable arena chunk size. Defaults to ARENA_CHUNK_SIZE; user can
// override via runtime.SetArenaChunkSize for embedded / memory-tight
// scenarios. volt_alloc reads this atomically when growing arenas.
static i64           g_arena_chunk_size = ARENA_CHUNK_SIZE;

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

// ---------------------------------------------------------------------
// Thread-local storage (TLS)
//
// volt is freestanding (no libc) and built with -fno-stack-protector,
// so the thread register (x86-64 %fs / aarch64 tpidr_el0) is entirely
// unused by the rest of the runtime — we're free to repurpose it. Each
// thread points its thread register at a small mmap'd per-thread block;
// volt_tls_init runs once per thread (from _start for the main thread,
// from volt_spawn's child for workers). Slot 0 currently backs the
// memory-profiler's per-thread "current source line"; more per-thread
// state can be added at higher offsets.
//
// TLS is only READ/WRITTEN under `--memprofile` (the note-line emission
// and the g_mp_line_enabled-gated alloc path), so a thread that never
// profiles never touches its TLS block.
#define TLS_BLOCK_SIZE 64

#if defined(__x86_64__)
#define SYS_ARCH_PRCTL 158
#define ARCH_SET_FS    0x1002
#endif

// Shared fallback TLS block, used only if a thread's per-thread mmap
// fails (hard-OOM). Pointing the thread register here keeps the gated
// accessors hitting VALID memory — worst case under OOM is a mis-
// attributed profile line, never a NULL-deref at %fs:0 / *(tpidr).
static i64 g_tls_fallback[TLS_BLOCK_SIZE / 8] = {0};

// Deadlock backstop (#7 stage 2) — atomic thread accounting.
//   g_live_threads : threads that currently exist. Starts at 1 (main).
//                    Codegen emits volt_thread_begin() BEFORE each
//                    volt_spawn (parent-side, so a worker is counted
//                    before it can ever park — no race window), and the
//                    spawn-child assembly calls volt_thread_exit() after
//                    the worker's function returns.
//   g_parked       : threads currently inside a tracked FUTEX_WAIT.
//   g_progress     : bumped on every FUTEX_WAKE (a thread made another
//                    runnable). When every live thread is parked and
//                    g_progress holds steady across the grace window, no
//                    thread can ever issue a wake → permanent deadlock.
static i32 g_live_threads = 1;
static i32 g_parked       = 0;
static i64 g_progress     = 0;

// volt_thread_begin / volt_thread_exit bracket a spawned worker's life.
// begin is emitted by codegen just before volt_spawn; exit is called from
// the volt_spawn child (start_*.s) right after the worker fn returns and
// before its sys_exit. The main thread is the static +1 and never calls
// exit (it tears the process down via sys_exit_group).
void volt_thread_begin(void) {
    __atomic_add_fetch(&g_live_threads, 1, __ATOMIC_SEQ_CST);
}
void volt_thread_exit(void) {
    __atomic_sub_fetch(&g_live_threads, 1, __ATOMIC_SEQ_CST);
}

// Forward decl: defined later (alongside its sys_rt_sigaction helper), but
// invoked once from volt_tls_init below to disarm SIGPIPE process-wide.
static void volt_ignore_sigpipe(void);

// volt_tls_init allocates this thread's TLS block and points the thread
// register at it. On mmap failure it degrades to the shared fallback
// block so the (profiling-gated) accessors never fault. Called once
// per thread (from _start for main, volt_spawn child for workers).
void volt_tls_init(void) {
    // Disarm SIGPIPE once, on the first (main-thread) init — before main
    // runs and before any worker spawns, so a write to a closed pipe/socket
    // returns -EPIPE instead of killing the process. Idempotent anyway.
    static int sigpipe_done = 0;
    if (!sigpipe_done) {
        sigpipe_done = 1;
        volt_ignore_sigpipe();
    }
    void* block = volt_mmap_anon(TLS_BLOCK_SIZE);
    if (!block) {
        block = (void*)g_tls_fallback;   // OOM: degrade, don't crash
    } else {
        for (i32 i = 0; i < TLS_BLOCK_SIZE; i++) ((char*)block)[i] = 0;
    }
#if defined(__x86_64__)
    register i64 rax __asm__("rax") = SYS_ARCH_PRCTL;
    register i64 rdi __asm__("rdi") = ARCH_SET_FS;
    register i64 rsi __asm__("rsi") = (i64)block;
    __asm__ volatile("syscall" : "+r"(rax) : "r"(rdi), "r"(rsi) : "rcx", "r11", "memory");
#elif defined(__aarch64__)
    __asm__ volatile("msr tpidr_el0, %0" :: "r"(block) : "memory");
#endif
}

// volt_tls_get_slot0 / volt_tls_set_slot0 read/write the i64 at offset 0
// of this thread's TLS block. On x86-64 %fs:0 directly addresses the
// block; on aarch64 tpidr_el0 holds the block pointer, so we load from
// it. Caller must have run volt_tls_init on this thread first.
static inline i64 volt_tls_get_slot0(void) {
    i64 v = 0;
#if defined(__x86_64__)
    __asm__ volatile("movq %%fs:0, %0" : "=r"(v));
#elif defined(__aarch64__)
    void* base;
    __asm__ volatile("mrs %0, tpidr_el0" : "=r"(base));
    v = *(volatile i64*)base;
#endif
    return v;
}
static inline void volt_tls_set_slot0(i64 v) {
#if defined(__x86_64__)
    __asm__ volatile("movq %0, %%fs:0" :: "r"(v) : "memory");
#elif defined(__aarch64__)
    void* base;
    __asm__ volatile("mrs %0, tpidr_el0" : "=r"(base));
    *(volatile i64*)base = v;
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

// Forward decl: defined in the heap-range-tracker block below. Called
// from volt_alloc to record mmap'd arena chunks + huge allocations.
static void heap_range_record(char* start, i64 size);

// Allocation counters for the heap-snapshot API. Bumped under
// alloc_lock so callers see consistent counts vs heap_bytes.
// `g_alloc_count`: total volt_alloc calls (lifetime, never decrements).
// `g_free_count`:  total volt_free  calls (lifetime, never decrements).
// `g_live_bytes`:  signed delta of (alloc payload) - (free payload).
//                   approximate live-allocation footprint; doesn't
//                   include the BLOCK_HDR_SIZE overhead per block.
static i64 g_alloc_count = 0;
static i64 g_free_count  = 0;
static i64 g_live_bytes  = 0;

// Per-size-class breakdown for runtime.HeapSnapshot (item 2) and the
// memory profiler (item 3). All bumped under alloc_lock.
//   g_live_count_class[sc]  — CURRENTLY-live block count in class sc
//                             (alloc++ / free--). Index NUM_SIZE_CLASSES
//                             would be the "huge" bucket but we keep it
//                             separate so the array stays exactly sized.
//   g_alloc_count_class[sc] — LIFETIME alloc count in class sc (memprofile).
//   g_alloc_bytes_class[sc] — LIFETIME slot bytes handed out in class sc.
// The *_huge scalars track mmap-direct (>32 KiB) allocations.
static i64 g_live_count_class[NUM_SIZE_CLASSES]  = {0};
static i64 g_alloc_count_class[NUM_SIZE_CLASSES] = {0};
static i64 g_alloc_bytes_class[NUM_SIZE_CLASSES] = {0};
static i64 g_live_count_huge  = 0;
static i64 g_alloc_count_huge = 0;
static i64 g_alloc_bytes_huge = 0;

// Call-site (source-line) allocation profiling. Enabled by
// `volt build --memprofile` (set_path turns g_mp_line_enabled on).
// Each thread stamps its current source line via
// volt_memprofile_note_line; volt_alloc folds the allocation into a
// per-line bucket (linear-probe table) under alloc_lock. When
// disabled, volt_alloc skips the table entirely (one predicted-false
// branch). The line==0 bucket collects runtime-internal allocations
// (chan/map machinery) that ran without a user line stamped.
#define MP_LINE_SLOTS 1024
// The memory-profiler's "current source line" is now PER-THREAD, held
// in TLS slot 0 (see volt_tls_get_slot0 / set_slot0). _start and
// volt_spawn run volt_tls_init on every thread, so each thread tracks
// its own line and attribution is exact under multithreading. Accessed
// only when g_mp_line_enabled (i.e. under --memprofile).
static i32 g_mp_line_enabled  = 0;
// Keys are stored as (line + 1) so a zero slot means "empty". The
// line==0 bucket (runtime-internal allocs) therefore stores key 1.
static i64 g_mp_line_keys[MP_LINE_SLOTS]  = {0};
static i64 g_mp_line_count[MP_LINE_SLOTS] = {0};
static i64 g_mp_line_bytes[MP_LINE_SLOTS] = {0};
static i32 g_mp_line_used = 0;                     // distinct lines recorded

// mp_line_record folds one allocation (slot bytes) into the per-line
// table. Caller holds alloc_lock. Linear-probe on (line+1). When the
// table fills (>MP_LINE_SLOTS distinct lines — generous for real
// programs), extra allocations fold into slot 0 (documented approx).
static void mp_line_record(i64 line, i64 slot_bytes) {
    i64 stored = line + 1;
    i64 home = stored & (MP_LINE_SLOTS - 1);
    for (i32 i = 0; i < MP_LINE_SLOTS; i++) {
        i64 idx = (home + i) & (MP_LINE_SLOTS - 1);
        if (g_mp_line_keys[idx] == stored) {
            g_mp_line_count[idx]++;
            g_mp_line_bytes[idx] += slot_bytes;
            return;
        }
        if (g_mp_line_keys[idx] == 0) {
            g_mp_line_keys[idx] = stored;
            g_mp_line_count[idx] = 1;
            g_mp_line_bytes[idx] = slot_bytes;
            g_mp_line_used++;
            return;
        }
    }
    g_mp_line_count[0]++;
    g_mp_line_bytes[0] += slot_bytes;
}

void* volt_alloc(i64 size) {
    if (size <= 0) return (void*)0;
    i32 sc = find_size_class(size);

    // Must be declared before any goto / asm so the prelude — including the
    // mutex_lock — runs first.
    void* result;
    i64 mp_slot = 0;   // slot bytes of this alloc, for per-line profiling

    mutex_lock(&alloc_lock);
    g_alloc_count++;
    // Track full-slot bytes so alloc/free balance — freed blocks return
    // their entire size-class bucket to the live-bytes tally.

    if (sc < 0) {
        // Huge: mmap-direct. Round to page (4 KiB) so munmap takes it back.
        i64 total = (BLOCK_HDR_SIZE + size + 4095) & ~4095;
        block_hdr_t* hdr = (block_hdr_t*)volt_mmap_anon(total);
        if (hdr) heap_range_record((char*)hdr, total);
        if (!hdr) {
            mutex_unlock(&alloc_lock);
            volt_die();
        }
        hdr->tag = -1;
        hdr->huge_size = total;
        g_live_bytes += (total - BLOCK_HDR_SIZE);
        g_live_count_huge++;
        g_alloc_count_huge++;
        g_alloc_bytes_huge += (total - BLOCK_HDR_SIZE);
        mp_slot = total - BLOCK_HDR_SIZE;
        result = (char*)hdr + BLOCK_HDR_SIZE;
    } else if (freelists[sc]) {
        block_hdr_t* hdr = freelists[sc];
        freelists[sc] = (block_hdr_t*)hdr->tag;  // next link was stashed in tag
        hdr->tag = sc;                             // restore tag for free()
        hdr->huge_size = 0;
        g_live_bytes += size_class_bytes[sc];
        g_live_count_class[sc]++;
        g_alloc_count_class[sc]++;
        g_alloc_bytes_class[sc] += size_class_bytes[sc];
        mp_slot = size_class_bytes[sc];
        result = (char*)hdr + BLOCK_HDR_SIZE;
    } else {
        // Bump from current arena chunk.
        i64 block_size = BLOCK_HDR_SIZE + size_class_bytes[sc];
        if (arena_curr + block_size > arena_end) {
            i64 chunk = __atomic_load_n(&g_arena_chunk_size, __ATOMIC_ACQUIRE);
            if (block_size > chunk) chunk = (block_size + 4095) & ~(i64)4095;
            char* base = (char*)volt_mmap_anon(chunk);
            if (!base) {
                mutex_unlock(&alloc_lock);
                volt_die();
            }
            heap_range_record(base, chunk);
            arena_curr = base;
            arena_end  = base + chunk;
        }
        block_hdr_t* hdr = (block_hdr_t*)arena_curr;
        hdr->tag       = sc;
        hdr->huge_size = 0;
        arena_curr    += block_size;
        g_live_bytes += size_class_bytes[sc];
        g_live_count_class[sc]++;
        g_alloc_count_class[sc]++;
        g_alloc_bytes_class[sc] += size_class_bytes[sc];
        mp_slot = size_class_bytes[sc];
        result         = (char*)hdr + BLOCK_HDR_SIZE;
    }

    // Per-line attribution (opt-in via --memprofile). Folded under the
    // same lock so the line table stays consistent with the counters.
    if (g_mp_line_enabled) {
        mp_line_record(volt_tls_get_slot0(), mp_slot);
    }

    mutex_unlock(&alloc_lock);

    // Zero the user payload — callers expect fresh-allocated bytes to be
    // zero (the old bump relied on BSS zeroing; the freelist reuses memory).
    zero_bytes(result, size);
    return result;
}

// Forward decl so volt_slice_free / volt_map_free can call volt_free
// (which is defined immediately below them).
void volt_free(void* ptr);
// Forward decl: volt_map_free (defined below, before the map_t section)
// frees boxed map values via map_free_value, which is defined later
// alongside the map implementation.
static void map_free_value(i64 value_kind, i64 value);

// Forward decl: volt_race_acquire/release are defined in the D.1
// race-detector block but called by volt_chan_send/recv for per-
// message happens-before tracking. When -race is off the detector
// short-circuits to no-op so these calls are cheap.
void volt_race_acquire(void* ptr);
void volt_race_release(void* ptr);

// Heap-range tracker — records every mmap'd region returned by
// volt_mmap_anon so volt_str_free can verify a pointer originated in
// the heap before freeing it. Without this, freeing a string literal
// (whose ptr lies in .rodata) would corrupt the freelist. The list
// is append-only (we don't shrink) and small in practice — each entry
// is one arena chunk (multi-MB) or a huge-alloc block.
#define HEAP_RANGE_MAX 256
typedef struct { char* start; char* end; } heap_range_t;
static heap_range_t g_heap_ranges[HEAP_RANGE_MAX];
static i32          g_heap_range_count = 0;
static mutex_t      g_heap_range_lock  = {0};

static void heap_range_record(char* start, i64 size) {
    mutex_lock(&g_heap_range_lock);
    if (g_heap_range_count < HEAP_RANGE_MAX) {
        g_heap_ranges[g_heap_range_count].start = start;
        g_heap_ranges[g_heap_range_count].end   = start + size;
        g_heap_range_count++;
    }
    mutex_unlock(&g_heap_range_lock);
}

static i32 heap_range_contains(void* p) {
    char* ptr = (char*)p;
    i32 n = __atomic_load_n(&g_heap_range_count, __ATOMIC_ACQUIRE);
    for (i32 i = 0; i < n; i++) {
        if (ptr >= g_heap_ranges[i].start && ptr < g_heap_ranges[i].end) {
            return 1;
        }
    }
    return 0;
}

// volt_str_free frees the backing buffer of a heap-allocated string.
// Runtime-safe: the heap-range check rejects pointers that didn't come
// from volt_alloc (string literals in .rodata, foreign-allocated bytes)
// — those become silent no-ops rather than corrupting the freelist.
// Null-safe.
void volt_str_free(void* buf_ptr) {
    if (!buf_ptr) return;
    if (!heap_range_contains(buf_ptr)) return;
    volt_free(buf_ptr);
}

// volt_slice_free frees the backing buffer of a slice. The slice
// header lives at a user-side alloca; the buffer is what was returned
// by volt_alloc for the element storage. Passing 0 is a no-op so the
// codegen can emit unconditional drops and let null sentinels (set
// when ownership transferred) short-circuit the call.
void volt_slice_free(void* buf_ptr) {
    if (!buf_ptr) return;
    volt_free(buf_ptr);
}

// volt_slice_free_str_elems frees the per-element %string PAYLOADS of a
// []string backing buffer, then the buffer itself (#5 / S1b). Each element
// is a {char* ptr; i64 len} = 16 bytes; element i's backing pointer is the
// first 8 bytes at offset i*16. volt_str_free is heap-range-safe, so a
// literal-backed element (rodata ptr) is a harmless no-op. Codegen emits a
// call to this (instead of volt_slice_free) ONLY for a []string local the
// compiler proved is the SOLE owner of independent element payloads — reads
// copy out (S1a), writes move in, so no element payload is aliased elsewhere.
// Null buffer is a no-op.
void volt_slice_free_str_elems(void* buf_ptr, i64 len) {
    if (!buf_ptr) return;
    for (i64 i = 0; i < len; i++) {
        char* elem = *(char**)((char*)buf_ptr + i * 16);
        volt_str_free(elem);
    }
    volt_free(buf_ptr);
}

// volt_map_free frees a map's entries (each entry's map-owned key copy
// + the entry node), its buckets array, and the map_t header itself.
// Keys ARE owned by the entry as of the key-copy change in volt_map_set
// — each was copied from the caller's storage at insert time, so freeing
// them here is correct (no alias, no double-free with the caller's
// original). Kind-1 (boxed %string) VALUES are also map-owned and freed
// here via map_free_value — the value was moved into the map at set-time
// and map-get deep-copies, so the map is the sole owner of its backing.
// Other value kinds (plain i64, slice boxes) are not freed (slice value
// ownership is a documented follow-up). Passing 0 is a no-op so codegen
// can emit unconditional drops paired with nullify-on-move.
void volt_map_free(void* m_) {
    if (!m_) return;
    struct map_entry_lf { struct map_entry_lf* next; char* key_ptr; i64 key_len; i64 value; };
    struct map_t_local {
        mutex_t       lock;
        i64           count;
        i64           num_buckets;
        struct map_entry_lf** buckets;
        i64           value_kind;
    };
    struct map_t_local* m = (struct map_t_local*)m_;
    for (i64 i = 0; i < m->num_buckets; i++) {
        struct map_entry_lf* e = m->buckets[i];
        while (e) {
            struct map_entry_lf* next = e->next;
            map_free_value(m->value_kind, e->value);   // boxed value (if owned)
            volt_free(e->key_ptr);                      // map-owned key copy
            volt_free(e);
            e = next;
        }
    }
    volt_free(m->buckets);
    volt_free(m);
}

// volt_free returns a block to its size-class freelist, or munmaps it
// if it was a huge alloc. Passing 0 is a no-op (Go-style).
void volt_free(void* ptr) {
    if (!ptr) return;
    block_hdr_t* hdr = (block_hdr_t*)((char*)ptr - BLOCK_HDR_SIZE);
    i64 tag = hdr->tag;

    mutex_lock(&alloc_lock);
    g_free_count++;
    if (tag < 0) {
        i64 huge = hdr->huge_size;
        // Subtract the user portion (huge minus header). Snapshot is
        // approximate — we don't recall the original `size` request,
        // only the page-rounded total mmap.
        g_live_bytes -= (huge - BLOCK_HDR_SIZE);
        g_live_count_huge--;
        mutex_unlock(&alloc_lock);
        volt_munmap(hdr, huge);
        return;
    }
    i32 sc = (i32)tag;
    g_live_bytes -= size_class_bytes[sc];
    g_live_count_class[sc]--;
    // Stash the next-link in tag (overwrites the size class — we'll
    // restore it in volt_alloc when this block is popped).
    hdr->tag = (i64)freelists[sc];
    freelists[sc] = hdr;
    mutex_unlock(&alloc_lock);
}

// volt_compact walks each size-class freelist, sorts entries by their
// arena address, and merges any pair of consecutive FREE blocks into
// a single larger block in the next-up size class. Runs under
// alloc_lock so it's safe vs concurrent volt_alloc/volt_free but
// blocks them for the duration.
//
// Merge math: two adjacent sc-blocks span `2 * (16 + sc_bytes)`
// bytes total. Treating that span as a single block with one header
// at offset 0 gives user-region size `16 + 2*sc_bytes`. Size class
// sc+1 has user size `2*sc_bytes` (the table doubles), so the merged
// block fits with 16 bytes of trailing waste — acceptable; the
// alternative would be a custom-size class table per merge.
//
// Iterative pass: after merging N pairs in sc into sc+1, the new
// sc+1 blocks become candidates for further merging if THEY end up
// adjacent. The outer loop runs over sc=0..NUM_SIZE_CLASSES-2.
// Per-class merges feed sc+1's freelist which is processed on the
// NEXT outer-loop iteration, so a single pass through sc handles up
// to one merge per pair. The user calls volt_compact() again for
// deeper consolidation if needed.
#define COMPACT_MAX_PER_CLASS 4096
static block_hdr_t* compact_buf[COMPACT_MAX_PER_CLASS];

void volt_compact(void) {
    mutex_lock(&alloc_lock);
    // Iterative: keep sweeping size classes until a full pass produces
    // zero merges. A single sweep handles all currently-adjacent
    // pairs at each size class; merged blocks land in sc+1's freelist
    // and become candidates on the NEXT pass at sc+1. Loop bound is
    // safety only — NUM_SIZE_CLASSES * 2 is plenty in practice
    // because each pass at level sc can only feed sc+1.
    i32 safety_iter = NUM_SIZE_CLASSES * 2;
    while (safety_iter-- > 0) {
        i64 merges_this_pass = 0;
    for (i32 sc = 0; sc < NUM_SIZE_CLASSES - 1; sc++) {
        // Drain freelist[sc] into compact_buf.
        i32 n = 0;
        block_hdr_t* head = freelists[sc];
        while (head && n < COMPACT_MAX_PER_CLASS) {
            block_hdr_t* next = (block_hdr_t*)head->tag;
            compact_buf[n++] = head;
            head = next;
        }
        // Preserve any tail beyond the buffer cap.
        block_hdr_t* tail = head;

        // Insertion sort by address.
        for (i32 i = 1; i < n; i++) {
            block_hdr_t* x = compact_buf[i];
            i32 j = i - 1;
            while (j >= 0 && (char*)compact_buf[j] > (char*)x) {
                compact_buf[j+1] = compact_buf[j];
                j--;
            }
            compact_buf[j+1] = x;
        }

        i64 block_size = BLOCK_HDR_SIZE + size_class_bytes[sc];
        // Reset freelist[sc] to the un-drained tail; we'll push back any
        // unmerged blocks plus the tail at the end.
        freelists[sc] = tail;
        for (i32 i = 0; i < n; ) {
            if (i + 1 < n) {
                block_hdr_t* a = compact_buf[i];
                block_hdr_t* b = compact_buf[i+1];
                if ((char*)a + block_size == (char*)b) {
                    // Merge: a now represents an sc+1-sized block. Push
                    // it onto freelists[sc+1] for further compaction
                    // on the next outer-loop iteration.
                    a->tag = (i64)freelists[sc+1];
                    a->huge_size = 0;
                    freelists[sc+1] = a;
                    merges_this_pass++;
                    i += 2;
                    continue;
                }
            }
            // No merge — push back to freelist[sc].
            block_hdr_t* x = compact_buf[i];
            x->tag = (i64)freelists[sc];
            freelists[sc] = x;
            i++;
        }
    }
        if (merges_this_pass == 0) break;
    }
    mutex_unlock(&alloc_lock);
}

// volt_runtime_thread_count is defined below alongside the race
// detector (where g_race_thread_count lives).
i64 volt_runtime_thread_count(void);

// Public setter for the arena chunk size (storage lives before
// volt_alloc for forward visibility). Clamps to [4 KiB, 256 MiB]
// and rounds up to the page boundary.

void volt_runtime_set_arena_chunk_size(i64 bytes) {
    if (bytes < 4096) bytes = 4096;    // page minimum
    if (bytes > (i64)256 * 1024 * 1024) bytes = (i64)256 * 1024 * 1024; // sanity cap
    // Round up to 4K page boundary.
    bytes = (bytes + 4095) & ~(i64)4095;
    __atomic_store_n(&g_arena_chunk_size, bytes, __ATOMIC_RELEASE);
}

// volt_runtime_heap_bytes returns the total bytes currently mmap'd
// for the allocator (sum of all heap_range_record entries). NOT the
// active-allocation count — fragmentation, freelist holes, and the
// current arena's unused tail all contribute. Call after Compact()
// for the most accurate "I'm using N bytes" reading.
i64 volt_runtime_heap_bytes(void) {
    i64 total = 0;
    i32 n = __atomic_load_n(&g_heap_range_count, __ATOMIC_ACQUIRE);
    for (i32 i = 0; i < n; i++) {
        total += (i64)(g_heap_ranges[i].end - g_heap_ranges[i].start);
    }
    return total;
}

// volt_runtime_freelist_count returns the number of FREE blocks in
// size-class `sc` (clamped to a valid range). 0 for any sc out of
// bounds. Surfaced via runtime.FreelistCounts which calls this for
// each class.
i64 volt_runtime_freelist_count(i64 sc) {
    if (sc < 0 || sc >= NUM_SIZE_CLASSES) return 0;
    i64 count = 0;
    mutex_lock(&alloc_lock);
    block_hdr_t* p = freelists[sc];
    while (p) {
        count++;
        p = (block_hdr_t*)p->tag;
    }
    mutex_unlock(&alloc_lock);
    return count;
}

// volt_runtime_num_size_classes returns the number of size classes
// — needed by runtime.FreelistCounts to size its output slice.
i64 volt_runtime_num_size_classes(void) {
    return (i64)NUM_SIZE_CLASSES;
}

// volt_runtime_alloc_count returns the lifetime alloc-call counter.
i64 volt_runtime_alloc_count(void) {
    return __atomic_load_n(&g_alloc_count, __ATOMIC_ACQUIRE);
}

// volt_runtime_free_count returns the lifetime free-call counter.
i64 volt_runtime_free_count(void) {
    return __atomic_load_n(&g_free_count, __ATOMIC_ACQUIRE);
}

// volt_runtime_live_bytes returns the approximate signed delta of
// (alloc payload) - (free payload). Counts size-class slot bytes
// rather than user-requested bytes — so a `volt_alloc(17)` that lands
// in the 32-byte class contributes 32 to live_bytes. Reads under no
// lock; the running write side bumps under alloc_lock so the
// loaded value is a snapshot that may be stale by the time the call
// returns.
i64 volt_runtime_live_bytes(void) {
    return __atomic_load_n(&g_live_bytes, __ATOMIC_ACQUIRE);
}

// volt_runtime_live_count_class returns the CURRENTLY-live block count
// in size class `sc` (alloc minus free for that class). Out-of-range
// sc returns 0. Backs runtime.HeapSnapshot's per-class breakdown.
i64 volt_runtime_live_count_class(i64 sc) {
    if (sc < 0 || sc >= NUM_SIZE_CLASSES) return 0;
    return __atomic_load_n(&g_live_count_class[sc], __ATOMIC_ACQUIRE);
}

// volt_runtime_live_count_huge returns the live count of mmap-direct
// (>32 KiB) allocations.
i64 volt_runtime_live_count_huge(void) {
    return __atomic_load_n(&g_live_count_huge, __ATOMIC_ACQUIRE);
}

// volt_runtime_alloc_count_class returns the LIFETIME alloc count in
// size class `sc` (never decrements). Memory-profiler accessor.
i64 volt_runtime_alloc_count_class(i64 sc) {
    if (sc < 0 || sc >= NUM_SIZE_CLASSES) return 0;
    return __atomic_load_n(&g_alloc_count_class[sc], __ATOMIC_ACQUIRE);
}

// volt_runtime_alloc_bytes_class returns the LIFETIME slot bytes handed
// out in size class `sc`.
i64 volt_runtime_alloc_bytes_class(i64 sc) {
    if (sc < 0 || sc >= NUM_SIZE_CLASSES) return 0;
    return __atomic_load_n(&g_alloc_bytes_class[sc], __ATOMIC_ACQUIRE);
}

// volt_runtime_size_class_bytes returns the byte capacity of size
// class `sc` (16, 32, 64, ...). Lets the snapshot label each bucket.
i64 volt_runtime_size_class_bytes(i64 sc) {
    if (sc < 0 || sc >= NUM_SIZE_CLASSES) return 0;
    return size_class_bytes[sc];
}

// volt_runtime_memprofile_reset zeroes the LIFETIME alloc histogram
// (count + bytes per class, plus the huge scalars). Live counts are
// untouched — they reflect outstanding allocations, not history.
// Lets a profiler scope a region: reset, run, dump.
void volt_runtime_memprofile_reset(void) {
    mutex_lock(&alloc_lock);
    for (i32 i = 0; i < NUM_SIZE_CLASSES; i++) {
        g_alloc_count_class[i] = 0;
        g_alloc_bytes_class[i] = 0;
    }
    g_alloc_count_huge = 0;
    g_alloc_bytes_huge = 0;
    // Also clear the per-line table so a scoped profile starts fresh.
    for (i32 i = 0; i < MP_LINE_SLOTS; i++) {
        g_mp_line_keys[i] = 0;
        g_mp_line_count[i] = 0;
        g_mp_line_bytes[i] = 0;
    }
    g_mp_line_used = 0;
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

// sys_futex_timed is FUTEX_WAIT with a RELATIVE timeout (the deadlock
// backstop's grace timer). timeout points to a {i64 sec; i64 nsec} laid
// out exactly like struct timespec. Returns the raw syscall result:
// 0 on a real wake, -EAGAIN(-11) if *uaddr already != val, -ETIMEDOUT
// (-110) on grace expiry, -EINTR(-4) on signal.
static i64 sys_futex_timed(i32* uaddr, i32 val, void* timeout) {
#if defined(__x86_64__)
    register i64 rax __asm__("rax") = SYS_FUTEX;
    register i64 rdi __asm__("rdi") = (i64)uaddr;
    register i64 rsi __asm__("rsi") = FUTEX_WAIT;
    register i64 rdx __asm__("rdx") = val;
    register i64 r10 __asm__("r10") = (i64)timeout;
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
    register i64 x1 __asm__("x1") = FUTEX_WAIT;
    register i64 x2 __asm__("x2") = val;
    register i64 x3 __asm__("x3") = (i64)timeout;
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

extern void volt_write(i64 fd, const char* buf, i64 len);

// deadlock_abort: the no-deadlock invariant's runtime half. A true
// deadlock would otherwise hang forever; instead we print a diagnostic
// and exit non-zero — the same clean exit_group path volt already uses
// for other unrecoverable runtime errors (volt_die). Never returns.
static void deadlock_abort(void) {
    static const char msg[] =
        "volt: fatal: deadlock detected — every thread is blocked and none can make progress\n";
    volt_write(2, msg, (i64)(sizeof(msg) - 1));
    volt_die();
}

// Grace timer + confirmation count for the all-blocked check. A real
// deadlock hangs forever, so detection latency is irrelevant; we trade it
// for safety. Aborting only after the all-parked + no-progress state
// PERSISTS across several grace windows makes a false positive on a live
// program effectively impossible: waking a parked thread requires a
// RUNNING thread to FUTEX_WAKE it, so once every thread is parked the
// state cannot change — and the multi-window confirmation plus the
// g_progress epoch rule out the microsecond "woken but not yet
// decremented" accounting window.
#define DEADLOCK_GRACE_NS      250000000   /* 250 ms per window */
#define DEADLOCK_CONFIRMATIONS 4           /* ~1.25 s of confirmed all-blocked */

// futex_wait_tracked performs a FUTEX_WAIT with deadlock accounting. It
// stays counted as parked for its whole blocked life: on our grace
// timeout it re-checks the all-blocked condition and loops (still parked)
// rather than returning, so a periodic wake never makes the caller see a
// spurious unblock. It returns to the caller only on a real wake or a
// value-change (which the caller's own retry loop re-tests).
static void futex_wait_tracked(i32* uaddr, i32 val) {
    __atomic_add_fetch(&g_parked, 1, __ATOMIC_SEQ_CST);
    struct { i64 sec; i64 nsec; } ts;
    ts.sec  = 0;
    ts.nsec = DEADLOCK_GRACE_NS;
    i64 baseline      = 0;
    i32 have_baseline = 0;
    i32 confirms      = 0;
    for (;;) {
        i64 r = sys_futex_timed(uaddr, val, &ts);
        if (r != -110 /* -ETIMEDOUT */) {
            if (r == -4 /* -EINTR */) {
                continue;   // spurious signal — keep waiting, stay parked
            }
            break;          // real wake (0) or value changed (-EAGAIN)
        }
        // Grace timer fired — evaluate the all-blocked condition.
        i32 parked = __atomic_load_n(&g_parked, __ATOMIC_SEQ_CST);
        i32 live   = __atomic_load_n(&g_live_threads, __ATOMIC_SEQ_CST);
        i64 prog   = __atomic_load_n(&g_progress, __ATOMIC_SEQ_CST);
        if (live > 0 && parked >= live) {
            if (have_baseline && prog == baseline) {
                if (++confirms >= DEADLOCK_CONFIRMATIONS) {
                    deadlock_abort();
                }
            } else {
                baseline      = prog;   // start/refresh the no-progress window
                have_baseline = 1;
                confirms      = 0;
            }
        } else {
            have_baseline = 0;          // a thread is runnable / progressed
            confirms      = 0;
        }
        // loop back and re-wait, still counted as parked.
    }
    __atomic_sub_fetch(&g_parked, 1, __ATOMIC_SEQ_CST);
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
        futex_wait_tracked(&m->state, 2);
    }
}

static void mutex_unlock(mutex_t* m) {
    i32 prev = __atomic_exchange_n(&m->state, 0, __ATOMIC_RELEASE);
    if (prev == 2) {
        __atomic_add_fetch(&g_progress, 1, __ATOMIC_RELAXED);  // a waiter is being woken
        sys_futex(&m->state, FUTEX_WAKE, 1);
    }
}

static void cond_wait(cond_t* c, mutex_t* m) {
    i32 seq = __atomic_load_n(&c->seq, __ATOMIC_ACQUIRE);
    mutex_unlock(m);
    futex_wait_tracked(&c->seq, seq);
    mutex_lock(m);
}

static void cond_signal(cond_t* c) {
    __atomic_add_fetch(&c->seq, 1, __ATOMIC_RELEASE);
    __atomic_add_fetch(&g_progress, 1, __ATOMIC_RELAXED);
    sys_futex(&c->seq, FUTEX_WAKE, 1);
}

static void cond_broadcast(cond_t* c) {
    __atomic_add_fetch(&c->seq, 1, __ATOMIC_RELEASE);
    __atomic_add_fetch(&g_progress, 1, __ATOMIC_RELAXED);
    sys_futex(&c->seq, FUTEX_WAKE, 0x7fffffff);
}

// ---------------------------------------------------------------------
// Blocking channel — element-size parameterized.
// The buffer is `cap * elem_size` raw bytes; send/recv memcpy at the
// slot offset. send takes a pointer to the value; recv takes a pointer
// to the destination. Channel handle is opaque (`ptr`) for users.
// ---------------------------------------------------------------------

// A channel is a futex mutex + two condvars guarding a ring buffer.
// cap=0 is an unbuffered rendezvous (synchronous handoff); cap>0 buffers.
//
// NOTE (future research): this is volt's single channel implementation.
// A lock-free MPMC ring backend (selectable via `--channels lockfree`)
// was prototyped and removed to keep the model simple — blocking ops
// should park, not spin, and one backend is far easier to reason about
// (it's also what the deadlock backstop relies on). See the
// "channel backend research" note in TODO.md before reintroducing one.
typedef struct {
    i64      refcount;     // atomic; volt_chan_new=1, retain/release, free at 0
    mutex_t  lock;
    cond_t   not_full;
    cond_t   not_empty;
    i64      cap;          // user-facing capacity: 0 = unbuffered (rendezvous)
    i64      len;
    i64      head;
    i64      tail;
    i64      closed;
    i64      elem_size;    // bytes per slot
    void*    buf;          // (cap || 1) * elem_size bytes
    i64      has_handoff;
    i64      receivers_parked;
} chan_t;

static void chan_memcpy(void* dst, void* src, i64 n) {
    u8* d = (u8*)dst;
    u8* s = (u8*)src;
    for (i64 i = 0; i < n; i++) d[i] = s[i];
}

static void* chan_slot(chan_t* c, i64 idx) {
    return (void*)((u8*)c->buf + idx * c->elem_size);
}

void* volt_chan_new(i64 cap, i64 elem_size) {
    if (cap < 0) cap = 0;
    if (elem_size <= 0) elem_size = 8;
    chan_t* c = (chan_t*)volt_alloc((i64)sizeof(chan_t));
    c->refcount = 1;
    c->lock.state    = 0;
    c->not_full.seq  = 0;
    c->not_empty.seq = 0;
    c->cap    = cap;
    c->len    = 0;
    c->head   = 0;
    c->tail   = 0;
    c->closed = 0;
    c->elem_size = elem_size;
    c->has_handoff = 0;
    c->receivers_parked = 0;
    i64 slots = cap;
    if (slots == 0) slots = 1; // always have a rendezvous slot for cap=0
    c->buf = volt_alloc(slots * elem_size);
    return (void*)c;
}

// Channel reference counting (#6). A channel is a SHARED handle — the creator
// plus each goroutine that captured it (`run f(c)`). volt_chan_new starts the
// count at 1 (the creator); retain adds the goroutine's ref before a spawn;
// release drops a ref at the creator's scope-end and at each goroutine's end;
// the last release frees the struct + its buffer. Null-safe.
void volt_chan_retain(void* ch_) {
    if (!ch_) return;
    __atomic_fetch_add(&((chan_t*)ch_)->refcount, 1, __ATOMIC_RELAXED);
}

void volt_chan_release(void* ch_) {
    if (!ch_) return;
    if (__atomic_sub_fetch(&((chan_t*)ch_)->refcount, 1, __ATOMIC_ACQ_REL) != 0) return;
    // Last holder dropped: no concurrent users remain (any goroutine still
    // using or parked on the channel holds a ref), so freeing is safe.
    chan_t* c = (chan_t*)ch_;
    volt_free(c->buf);
    volt_free(c);
}

void volt_chan_send(void* ch_, void* val_src) {
    chan_t* c = (chan_t*)ch_;
    mutex_lock(&c->lock);
    if (c->cap == 0) {
        while (c->has_handoff && !c->closed) {
            cond_wait(&c->not_full, &c->lock);
        }
        if (c->closed) {
            mutex_unlock(&c->lock);
            volt_die();
        }
        chan_memcpy(chan_slot(c, 0), val_src, c->elem_size);
        // Channel/race convergence: publish the sender's HB clock at
        // the SLOT address (not the channel address), so each message
        // gets its own happens-before edge. Lets the race detector
        // distinguish "msg N before msg M" without false sharing.
        volt_race_release(chan_slot(c, 0));
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
        volt_die();
    }
    void* slot = chan_slot(c, c->tail);
    chan_memcpy(slot, val_src, c->elem_size);
    // Per-message HB: publish at the slot address.
    volt_race_release(slot);
    c->tail = (c->tail + 1) % c->cap;
    c->len++;
    cond_signal(&c->not_empty);
    mutex_unlock(&c->lock);
}

// Returns 1 on success, 0 if channel closed+drained (val_dest is zeroed).
i64 volt_chan_recv(void* ch_, void* val_dest) {
    chan_t* c = (chan_t*)ch_;
    mutex_lock(&c->lock);
    if (c->cap == 0) {
        c->receivers_parked++;
        while (!c->has_handoff && !c->closed) {
            cond_wait(&c->not_empty, &c->lock);
        }
        c->receivers_parked--;
        if (!c->has_handoff && c->closed) {
            mutex_unlock(&c->lock);
            u8* d = (u8*)val_dest;
            for (i64 i = 0; i < c->elem_size; i++) d[i] = 0;
            return 0;
        }
        // Per-message HB: acquire the sender's clock at the slot.
        volt_race_acquire(chan_slot(c, 0));
        chan_memcpy(val_dest, chan_slot(c, 0), c->elem_size);
        c->has_handoff = 0;
        cond_signal(&c->not_full);
        mutex_unlock(&c->lock);
        return 1;
    }
    while (c->len == 0 && !c->closed) {
        cond_wait(&c->not_empty, &c->lock);
    }
    if (c->len == 0 && c->closed) {
        mutex_unlock(&c->lock);
        u8* d = (u8*)val_dest;
        for (i64 i = 0; i < c->elem_size; i++) d[i] = 0;
        return 0;
    }
    void* slot = chan_slot(c, c->head);
    // Per-message HB.
    volt_race_acquire(slot);
    chan_memcpy(val_dest, slot, c->elem_size);
    c->head = (c->head + 1) % c->cap;
    c->len--;
    cond_signal(&c->not_full);
    mutex_unlock(&c->lock);
    return 1;
}

void volt_chan_close(void* ch_) {
    chan_t* c = (chan_t*)ch_;
    mutex_lock(&c->lock);
    c->closed = 1;
    cond_broadcast(&c->not_empty);
    cond_broadcast(&c->not_full);
    mutex_unlock(&c->lock);
}

// Non-blocking send. Returns 1 if value was queued, 0 if full.
// On a cap=0 channel: succeeds only if a receiver is parked.
i64 volt_chan_try_send(void* ch_, void* val_src) {
    chan_t* c = (chan_t*)ch_;
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
        chan_memcpy(chan_slot(c, 0), val_src, c->elem_size);
        c->has_handoff = 1;
        cond_signal(&c->not_empty);
        mutex_unlock(&c->lock);
        return 1;
    }
    if (c->len >= c->cap) {
        mutex_unlock(&c->lock);
        return 0;
    }
    chan_memcpy(chan_slot(c, c->tail), val_src, c->elem_size);
    c->tail = (c->tail + 1) % c->cap;
    c->len++;
    cond_signal(&c->not_empty);
    mutex_unlock(&c->lock);
    return 1;
}

// Non-blocking recv. Returns 1 if value was dequeued, 0 if empty.
// On a cap=0 channel: succeeds only if a sender's handoff is pending.
// Writes the dequeued bytes to *val_dest on success; zeroes on closed+empty.
i64 volt_chan_try_recv(void* ch_, void* val_dest) {
    chan_t* c = (chan_t*)ch_;
    mutex_lock(&c->lock);
    if (c->cap == 0) {
        if (!c->has_handoff) {
            mutex_unlock(&c->lock);
            return 0;
        }
        chan_memcpy(val_dest, chan_slot(c, 0), c->elem_size);
        c->has_handoff = 0;
        cond_signal(&c->not_full);
        mutex_unlock(&c->lock);
        return 1;
    }
    if (c->len == 0) {
        mutex_unlock(&c->lock);
        return 0;
    }
    chan_memcpy(val_dest, chan_slot(c, c->head), c->elem_size);
    c->head = (c->head + 1) % c->cap;
    c->len--;
    cond_signal(&c->not_full);
    mutex_unlock(&c->lock);
    return 1;
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

// volt_remove unlinks the entry at `path`. Mirrors Go's os.Remove:
// tries a plain unlinkat first (works for files); on EISDIR retries
// with AT_REMOVEDIR (works for empty directories). Returns 0 on
// success or -errno.
i64 volt_remove(const char* path_ptr, i64 path_len) {
    if (path_len < 0 || path_len > 4095) return -36; // ENAMETOOLONG
    char nbuf[4096];
    for (i64 i = 0; i < path_len; i++) nbuf[i] = path_ptr[i];
    nbuf[path_len] = 0;
    i64 rc;
#if defined(__x86_64__)
    {
        register i64 rax __asm__("rax") = SYS_UNLINKAT;
        register i64 rdi __asm__("rdi") = AT_FDCWD;
        register i64 rsi __asm__("rsi") = (i64)nbuf;
        register i64 rdx __asm__("rdx") = 0;
        __asm__ volatile("syscall"
            : "+r"(rax)
            : "r"(rdi), "r"(rsi), "r"(rdx)
            : "rcx", "r11", "memory");
        rc = rax;
    }
    if (rc == -21) {
        register i64 rax __asm__("rax") = SYS_UNLINKAT;
        register i64 rdi __asm__("rdi") = AT_FDCWD;
        register i64 rsi __asm__("rsi") = (i64)nbuf;
        register i64 rdx __asm__("rdx") = 0x200; // AT_REMOVEDIR
        __asm__ volatile("syscall"
            : "+r"(rax)
            : "r"(rdi), "r"(rsi), "r"(rdx)
            : "rcx", "r11", "memory");
        rc = rax;
    }
#elif defined(__aarch64__)
    {
        register i64 x8 __asm__("x8") = SYS_UNLINKAT;
        register i64 x0 __asm__("x0") = AT_FDCWD;
        register i64 x1 __asm__("x1") = (i64)nbuf;
        register i64 x2 __asm__("x2") = 0;
        __asm__ volatile("svc #0"
            : "+r"(x0)
            : "r"(x8), "r"(x1), "r"(x2)
            : "memory");
        rc = x0;
    }
    if (rc == -21) {
        register i64 x8 __asm__("x8") = SYS_UNLINKAT;
        register i64 x0 __asm__("x0") = AT_FDCWD;
        register i64 x1 __asm__("x1") = (i64)nbuf;
        register i64 x2 __asm__("x2") = 0x200;
        __asm__ volatile("svc #0"
            : "+r"(x0)
            : "r"(x8), "r"(x1), "r"(x2)
            : "memory");
        rc = x0;
    }
#endif
    return rc;
}

// volt_mkdir creates the directory at `path` with the given mode
// (POSIX permission bits, typically 0755). Returns 0 on success or
// -errno. The path is copied to a NUL-terminated scratch buffer.
i64 volt_mkdir(const char* path_ptr, i64 path_len, i64 mode) {
    if (path_len < 0 || path_len > 4095) return -36; // ENAMETOOLONG
    char nbuf[4096];
    for (i64 i = 0; i < path_len; i++) nbuf[i] = path_ptr[i];
    nbuf[path_len] = 0;
#if defined(__x86_64__)
    register i64 rax __asm__("rax") = SYS_MKDIRAT;
    register i64 rdi __asm__("rdi") = AT_FDCWD;
    register i64 rsi __asm__("rsi") = (i64)nbuf;
    register i64 rdx __asm__("rdx") = mode;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx)
        : "rcx", "r11", "memory");
    return rax;
#elif defined(__aarch64__)
    register i64 x8 __asm__("x8") = SYS_MKDIRAT;
    register i64 x0 __asm__("x0") = AT_FDCWD;
    register i64 x1 __asm__("x1") = (i64)nbuf;
    register i64 x2 __asm__("x2") = mode;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2)
        : "memory");
    return x0;
#endif
}

// volt_path_exists returns 1 if `path` is accessible (F_OK = 0 means
// "test for existence"), 0 if not. Implemented via faccessat(2).
i64 volt_path_exists(const char* path_ptr, i64 path_len) {
    if (path_len < 0 || path_len > 4095) return 0;
    char nbuf[4096];
    for (i64 i = 0; i < path_len; i++) nbuf[i] = path_ptr[i];
    nbuf[path_len] = 0;
    i64 rc;
#if defined(__x86_64__)
    register i64 rax __asm__("rax") = SYS_FACCESSAT;
    register i64 rdi __asm__("rdi") = AT_FDCWD;
    register i64 rsi __asm__("rsi") = (i64)nbuf;
    register i64 rdx __asm__("rdx") = 0; // F_OK
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx)
        : "rcx", "r11", "memory");
    rc = rax;
#elif defined(__aarch64__)
    register i64 x8 __asm__("x8") = SYS_FACCESSAT;
    register i64 x0 __asm__("x0") = AT_FDCWD;
    register i64 x1 __asm__("x1") = (i64)nbuf;
    register i64 x2 __asm__("x2") = 0;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2)
        : "memory");
    rc = x0;
#endif
    return rc == 0 ? 1 : 0;
}

// volt_getrandom fills `buf[0..n]` with cryptographically-random
// bytes via the Linux getrandom(2) syscall. Returns the number of
// bytes actually written (≤ n) on success, or -errno on failure.
// flags = 0 (blocks until kernel entropy is available; matches Go's
// crypto/rand semantics for short reads).
i64 volt_getrandom(char* buf, i64 n) {
    if (n <= 0) return 0;
#if defined(__x86_64__)
    register i64 rax __asm__("rax") = SYS_GETRANDOM;
    register i64 rdi __asm__("rdi") = (i64)buf;
    register i64 rsi __asm__("rsi") = n;
    register i64 rdx __asm__("rdx") = 0; // flags
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx)
        : "rcx", "r11", "memory");
    return rax;
#elif defined(__aarch64__)
    register i64 x8 __asm__("x8") = SYS_GETRANDOM;
    register i64 x0 __asm__("x0") = (i64)buf;
    register i64 x1 __asm__("x1") = n;
    register i64 x2 __asm__("x2") = 0;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2)
        : "memory");
    return x0;
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
// File I/O — direct syscalls (no libc).
// Returns: nonnegative on success; negative -errno on failure
// (matches the Linux kernel ABI directly).
// ---------------------------------------------------------------------

#if defined(__x86_64__)
static i64 sys_openat(i64 dirfd, const char* path, i64 flags, i64 mode) {
    register i64 rax __asm__("rax") = SYS_OPENAT;
    register i64 rdi __asm__("rdi") = dirfd;
    register i64 rsi __asm__("rsi") = (i64)path;
    register i64 rdx __asm__("rdx") = flags;
    register i64 r10 __asm__("r10") = mode;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10)
        : "rcx", "r11", "memory");
    return rax;
}
static i64 sys_read(i64 fd, void* buf, i64 n) {
    register i64 rax __asm__("rax") = SYS_READ;
    register i64 rdi __asm__("rdi") = fd;
    register i64 rsi __asm__("rsi") = (i64)buf;
    register i64 rdx __asm__("rdx") = n;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx)
        : "rcx", "r11", "memory");
    return rax;
}
static i64 sys_write_raw(i64 fd, const void* buf, i64 n) {
    register i64 rax __asm__("rax") = SYS_WRITE;
    register i64 rdi __asm__("rdi") = fd;
    register i64 rsi __asm__("rsi") = (i64)buf;
    register i64 rdx __asm__("rdx") = n;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx)
        : "rcx", "r11", "memory");
    return rax;
}
static i64 sys_close(i64 fd) {
    register i64 rax __asm__("rax") = SYS_CLOSE;
    register i64 rdi __asm__("rdi") = fd;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi)
        : "rcx", "r11", "memory");
    return rax;
}
#elif defined(__aarch64__)
static i64 sys_openat(i64 dirfd, const char* path, i64 flags, i64 mode) {
    register i64 x8 __asm__("x8") = SYS_OPENAT;
    register i64 x0 __asm__("x0") = dirfd;
    register i64 x1 __asm__("x1") = (i64)path;
    register i64 x2 __asm__("x2") = flags;
    register i64 x3 __asm__("x3") = mode;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2), "r"(x3)
        : "memory");
    return x0;
}
static i64 sys_read(i64 fd, void* buf, i64 n) {
    register i64 x8 __asm__("x8") = SYS_READ;
    register i64 x0 __asm__("x0") = fd;
    register i64 x1 __asm__("x1") = (i64)buf;
    register i64 x2 __asm__("x2") = n;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2)
        : "memory");
    return x0;
}
static i64 sys_write_raw(i64 fd, const void* buf, i64 n) {
    register i64 x8 __asm__("x8") = SYS_WRITE;
    register i64 x0 __asm__("x0") = fd;
    register i64 x1 __asm__("x1") = (i64)buf;
    register i64 x2 __asm__("x2") = n;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2)
        : "memory");
    return x0;
}
static i64 sys_close(i64 fd) {
    register i64 x8 __asm__("x8") = SYS_CLOSE;
    register i64 x0 __asm__("x0") = fd;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8)
        : "memory");
    return x0;
}
#endif

// ---- Terminal / poll syscall wrappers ------------------------------
// ioctl(fd, request, argp) drives TIOCGWINSZ (window size) and
// TCGETS/TCSETS (termios get/set) for the `term` stdlib package.
// ppoll(fds, nfds, timeout, sigmask, sigsetsize) backs PollIn — a
// readability wait with a millisecond timeout. Same shape per arch.
#if defined(__x86_64__)
static i64 sys_ioctl(i64 fd, i64 req, void* argp) {
    register i64 rax __asm__("rax") = SYS_IOCTL;
    register i64 rdi __asm__("rdi") = fd;
    register i64 rsi __asm__("rsi") = req;
    register i64 rdx __asm__("rdx") = (i64)argp;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx)
        : "rcx", "r11", "memory");
    return rax;
}
static i64 sys_ppoll(void* fds, i64 nfds, void* tmo, void* sig, i64 sigsz) {
    register i64 rax __asm__("rax") = SYS_PPOLL;
    register i64 rdi __asm__("rdi") = (i64)fds;
    register i64 rsi __asm__("rsi") = nfds;
    register i64 rdx __asm__("rdx") = (i64)tmo;
    register i64 r10 __asm__("r10") = (i64)sig;
    register i64 r8  __asm__("r8")  = sigsz;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10), "r"(r8)
        : "rcx", "r11", "memory");
    return rax;
}
#elif defined(__aarch64__)
static i64 sys_ioctl(i64 fd, i64 req, void* argp) {
    register i64 x8 __asm__("x8") = SYS_IOCTL;
    register i64 x0 __asm__("x0") = fd;
    register i64 x1 __asm__("x1") = req;
    register i64 x2 __asm__("x2") = (i64)argp;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2)
        : "memory");
    return x0;
}
static i64 sys_ppoll(void* fds, i64 nfds, void* tmo, void* sig, i64 sigsz) {
    register i64 x8 __asm__("x8") = SYS_PPOLL;
    register i64 x0 __asm__("x0") = (i64)fds;
    register i64 x1 __asm__("x1") = nfds;
    register i64 x2 __asm__("x2") = (i64)tmo;
    register i64 x3 __asm__("x3") = (i64)sig;
    register i64 x4 __asm__("x4") = sigsz;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2), "r"(x3), "r"(x4)
        : "memory");
    return x0;
}
#endif

// rt_sigaction(sig, act, oldact, sigsetsize). Used only to install SIG_IGN
// for SIGPIPE at startup (see volt_ignore_sigpipe).
#if defined(__x86_64__)
static i64 sys_rt_sigaction(i64 sig, void* act, void* oldact, i64 sigsz) {
    register i64 rax __asm__("rax") = SYS_RT_SIGACTION;
    register i64 rdi __asm__("rdi") = sig;
    register i64 rsi __asm__("rsi") = (i64)act;
    register i64 rdx __asm__("rdx") = (i64)oldact;
    register i64 r10 __asm__("r10") = sigsz;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10)
        : "rcx", "r11", "memory");
    return rax;
}
#elif defined(__aarch64__)
static i64 sys_rt_sigaction(i64 sig, void* act, void* oldact, i64 sigsz) {
    register i64 x8 __asm__("x8") = SYS_RT_SIGACTION;
    register i64 x0 __asm__("x0") = sig;
    register i64 x1 __asm__("x1") = (i64)act;
    register i64 x2 __asm__("x2") = (i64)oldact;
    register i64 x3 __asm__("x3") = sigsz;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2), "r"(x3)
        : "memory");
    return x0;
}
#endif

// volt_ignore_sigpipe installs SIG_IGN for SIGPIPE so that writing to a
// pipe/socket whose read end has closed returns -EPIPE instead of killing
// the whole process with the default SIGPIPE action. exec's stdin feed
// (writing Input to a child that may exit early, e.g. `head`) and socket
// writes both rely on this. Idempotent; called once from volt_tls_init on
// the main thread (before main, before any worker spawn).
//
// kernel struct sigaction { void* handler; u64 flags; void* restorer;
// u64 mask; }; sigsetsize = 8. SIG_IGN = 1. No restorer is needed because
// SIG_IGN never enters a handler. SIGPIPE = 13 on both linux/amd64+arm64.
static void volt_ignore_sigpipe(void) {
    i64 act[4];
    act[0] = 1;   // sa_handler = SIG_IGN
    act[1] = 0;   // sa_flags
    act[2] = 0;   // sa_restorer (unused for SIG_IGN)
    act[3] = 0;   // sa_mask
    sys_rt_sigaction(13, act, 0, 8);
}

// ---- Socket syscall wrappers ---------------------------------------
// Same shape per arch: rax/x8 holds the syscall number, args in the
// standard ABI registers. accept(2) is used (not accept4) for max
// compatibility — we don't pass flags.
#if defined(__x86_64__)
static i64 sys_socket(i64 domain, i64 type, i64 protocol) {
    register i64 rax __asm__("rax") = SYS_SOCKET;
    register i64 rdi __asm__("rdi") = domain;
    register i64 rsi __asm__("rsi") = type;
    register i64 rdx __asm__("rdx") = protocol;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx)
        : "rcx", "r11", "memory");
    return rax;
}
static i64 sys_bind(i64 fd, const void* addr, i64 addrlen) {
    register i64 rax __asm__("rax") = SYS_BIND;
    register i64 rdi __asm__("rdi") = fd;
    register i64 rsi __asm__("rsi") = (i64)addr;
    register i64 rdx __asm__("rdx") = addrlen;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx)
        : "rcx", "r11", "memory");
    return rax;
}
static i64 sys_listen(i64 fd, i64 backlog) {
    register i64 rax __asm__("rax") = SYS_LISTEN;
    register i64 rdi __asm__("rdi") = fd;
    register i64 rsi __asm__("rsi") = backlog;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi)
        : "rcx", "r11", "memory");
    return rax;
}
static i64 sys_accept(i64 fd, void* addr, void* addrlen) {
    register i64 rax __asm__("rax") = SYS_ACCEPT;
    register i64 rdi __asm__("rdi") = fd;
    register i64 rsi __asm__("rsi") = (i64)addr;
    register i64 rdx __asm__("rdx") = (i64)addrlen;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx)
        : "rcx", "r11", "memory");
    return rax;
}
static i64 sys_connect(i64 fd, const void* addr, i64 addrlen) {
    register i64 rax __asm__("rax") = SYS_CONNECT;
    register i64 rdi __asm__("rdi") = fd;
    register i64 rsi __asm__("rsi") = (i64)addr;
    register i64 rdx __asm__("rdx") = addrlen;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx)
        : "rcx", "r11", "memory");
    return rax;
}
static i64 sys_setsockopt(i64 fd, i64 level, i64 opt, const void* val, i64 vlen) {
    register i64 rax __asm__("rax") = SYS_SETSOCKOPT;
    register i64 rdi __asm__("rdi") = fd;
    register i64 rsi __asm__("rsi") = level;
    register i64 rdx __asm__("rdx") = opt;
    register i64 r10 __asm__("r10") = (i64)val;
    register i64 r8  __asm__("r8")  = vlen;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10), "r"(r8)
        : "rcx", "r11", "memory");
    return rax;
}
#elif defined(__aarch64__)
static i64 sys_socket(i64 domain, i64 type, i64 protocol) {
    register i64 x8 __asm__("x8") = SYS_SOCKET;
    register i64 x0 __asm__("x0") = domain;
    register i64 x1 __asm__("x1") = type;
    register i64 x2 __asm__("x2") = protocol;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2)
        : "memory");
    return x0;
}
static i64 sys_bind(i64 fd, const void* addr, i64 addrlen) {
    register i64 x8 __asm__("x8") = SYS_BIND;
    register i64 x0 __asm__("x0") = fd;
    register i64 x1 __asm__("x1") = (i64)addr;
    register i64 x2 __asm__("x2") = addrlen;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2)
        : "memory");
    return x0;
}
static i64 sys_listen(i64 fd, i64 backlog) {
    register i64 x8 __asm__("x8") = SYS_LISTEN;
    register i64 x0 __asm__("x0") = fd;
    register i64 x1 __asm__("x1") = backlog;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1)
        : "memory");
    return x0;
}
static i64 sys_accept(i64 fd, void* addr, void* addrlen) {
    register i64 x8 __asm__("x8") = SYS_ACCEPT;
    register i64 x0 __asm__("x0") = fd;
    register i64 x1 __asm__("x1") = (i64)addr;
    register i64 x2 __asm__("x2") = (i64)addrlen;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2)
        : "memory");
    return x0;
}
static i64 sys_connect(i64 fd, const void* addr, i64 addrlen) {
    register i64 x8 __asm__("x8") = SYS_CONNECT;
    register i64 x0 __asm__("x0") = fd;
    register i64 x1 __asm__("x1") = (i64)addr;
    register i64 x2 __asm__("x2") = addrlen;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2)
        : "memory");
    return x0;
}
static i64 sys_setsockopt(i64 fd, i64 level, i64 opt, const void* val, i64 vlen) {
    register i64 x8 __asm__("x8") = SYS_SETSOCKOPT;
    register i64 x0 __asm__("x0") = fd;
    register i64 x1 __asm__("x1") = level;
    register i64 x2 __asm__("x2") = opt;
    register i64 x3 __asm__("x3") = (i64)val;
    register i64 x4 __asm__("x4") = vlen;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2), "r"(x3), "r"(x4)
        : "memory");
    return x0;
}
#endif

// ---- High-level socket helpers exposed to volt ---------------------
// All return >= 0 on success, < 0 on error (negated errno).

// htons-style 16-bit byte swap for the port field of sockaddr_in.
// Linux is little-endian on amd64+arm64; network order = big-endian.
static unsigned short htons16(unsigned short x) {
    return (unsigned short)((x << 8) | (x >> 8));
}

// Encode AF_INET / port / addr into a 16-byte sockaddr_in scratch
// buffer. `ip32` is the host-order IPv4 address (e.g.
// 127.0.0.1 → 0x7F000001). `port` is the host-order port.
static void make_sockaddr_in(unsigned char out[16], i64 ip32, i64 port) {
    // sin_family (uint16, host byte order — kernel reads as native)
    out[0] = AF_INET & 0xFF;
    out[1] = (AF_INET >> 8) & 0xFF;
    // sin_port (uint16, network byte order = big-endian)
    out[2] = (port >> 8) & 0xFF;
    out[3] = port & 0xFF;
    // sin_addr (uint32, network byte order)
    out[4] = (ip32 >> 24) & 0xFF;
    out[5] = (ip32 >> 16) & 0xFF;
    out[6] = (ip32 >> 8) & 0xFF;
    out[7] = ip32 & 0xFF;
    // sin_zero[8]
    for (int i = 8; i < 16; i++) out[i] = 0;
    (void)htons16;
}

// volt_tcp_listen creates an AF_INET / SOCK_STREAM socket, binds it
// to (ip, port), and starts listening with the given backlog. Returns
// the listening fd or -errno. ip and port are host-order ints.
i64 volt_tcp_listen(i64 ip, i64 port, i64 backlog) {
    i64 fd = sys_socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (fd < 0) return fd;
    // SO_REUSEADDR so back-to-back listens don't hit TIME_WAIT.
    int one = 1;
    sys_setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
    unsigned char addr[16];
    make_sockaddr_in(addr, ip, port);
    i64 r = sys_bind(fd, addr, 16);
    if (r < 0) { sys_close(fd); return r; }
    r = sys_listen(fd, backlog);
    if (r < 0) { sys_close(fd); return r; }
    return fd;
}

// volt_tcp_accept blocks until a client connects, then returns the
// new conn fd (or -errno). We ignore the peer address.
i64 volt_tcp_accept(i64 listen_fd) {
    return sys_accept(listen_fd, 0, 0);
}

// volt_tcp_dial creates a socket and connects to (ip, port). Returns
// the connected fd or -errno.
i64 volt_tcp_dial(i64 ip, i64 port) {
    i64 fd = sys_socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (fd < 0) return fd;
    unsigned char addr[16];
    make_sockaddr_in(addr, ip, port);
    i64 r = sys_connect(fd, addr, 16);
    if (r < 0) { sys_close(fd); return r; }
    return fd;
}

// volt_open: opens `path` (a (ptr, len) byte sequence — volt strings
// don't carry a NUL terminator). Returns fd on success or -errno.
// The path is copied to a NUL-terminated scratch buffer for the syscall.
i64 volt_open(const char* path_ptr, i64 path_len, i64 flags, i64 mode) {
    if (path_len < 0 || path_len > 4095) return -36; // ENAMETOOLONG
    char nbuf[4096];
    for (i64 i = 0; i < path_len; i++) nbuf[i] = path_ptr[i];
    nbuf[path_len] = 0;
    return sys_openat(AT_FDCWD, nbuf, flags, mode);
}

// volt_close: closes fd. Returns 0 on success, -errno on failure.
i64 volt_close(i64 fd) {
    return sys_close(fd);
}

// mp_emit_i64 appends the base-10 ASCII of `n` to buf[*pos], advancing
// *pos. Local helper for the memory-profile JSON writer. cap guards
// against overflow (silently truncates rather than corrupt the stack).
static void mp_emit_i64(char* buf, i64* pos, i64 cap, i64 n) {
    char tmp[24];
    i32 t = 0;
    i32 neg = 0;
    u64 u;
    if (n < 0) { neg = 1; u = (u64)(-(n + 1)) + 1; } else { u = (u64)n; }
    if (u == 0) tmp[t++] = '0';
    while (u > 0) { tmp[t++] = (char)('0' + (i32)(u % 10)); u /= 10; }
    if (neg && *pos < cap) buf[(*pos)++] = '-';
    while (t > 0 && *pos < cap) buf[(*pos)++] = tmp[--t];
}

// mp_emit_str appends NUL-terminated literal `s` to buf[*pos].
static void mp_emit_str(char* buf, i64* pos, i64 cap, const char* s) {
    while (*s && *pos < cap) buf[(*pos)++] = *s++;
}

// volt_runtime_memprofile_dump writes the current allocation profile
// to `path` as JSON. Layout (one line):
//   {"size_classes":[{"bytes":16,"live":N,"alloc_count":M,"alloc_bytes":B},...],
//    "huge":{"live":N,"alloc_count":M,"alloc_bytes":B},
//    "totals":{"alloc_count":X,"free_count":Y,"live_bytes":Z}}
// Returns 0 on success, -errno on open/write failure. Snapshots the
// counters under alloc_lock so the dump is internally consistent.
// Static dump scratch (BSS, not stack) — the by_line array can run to
// hundreds of entries; keep it off the half-torn-down exit stack.
// Guarded by g_mp_dump_lock since two threads could race a dump.
static char   g_mp_dump_buf[65536];
static mutex_t g_mp_dump_lock = {0};

i64 volt_runtime_memprofile_dump(const char* path_ptr, i64 path_len) {
    // Snapshot everything under alloc_lock into locals so we don't hold
    // it during I/O. The per-line table is snapshotted too.
    i64 live_c[NUM_SIZE_CLASSES];
    i64 acnt_c[NUM_SIZE_CLASSES];
    i64 abyt_c[NUM_SIZE_CLASSES];
    i64 live_h, acnt_h, abyt_h, alloc_t, free_t, livebytes;
    static i64 ln_key[MP_LINE_SLOTS];
    static i64 ln_cnt[MP_LINE_SLOTS];
    static i64 ln_byt[MP_LINE_SLOTS];

    mutex_lock(&g_mp_dump_lock);
    mutex_lock(&alloc_lock);
    for (i32 i = 0; i < NUM_SIZE_CLASSES; i++) {
        live_c[i] = g_live_count_class[i];
        acnt_c[i] = g_alloc_count_class[i];
        abyt_c[i] = g_alloc_bytes_class[i];
    }
    live_h = g_live_count_huge;
    acnt_h = g_alloc_count_huge;
    abyt_h = g_alloc_bytes_huge;
    alloc_t = g_alloc_count;
    free_t = g_free_count;
    livebytes = g_live_bytes;
    for (i32 i = 0; i < MP_LINE_SLOTS; i++) {
        ln_key[i] = g_mp_line_keys[i];
        ln_cnt[i] = g_mp_line_count[i];
        ln_byt[i] = g_mp_line_bytes[i];
    }
    mutex_unlock(&alloc_lock);

    char* buf = g_mp_dump_buf;
    i64 pos = 0;
    i64 cap = sizeof(g_mp_dump_buf);
    mp_emit_str(buf, &pos, cap, "{\"size_classes\":[");
    for (i32 i = 0; i < NUM_SIZE_CLASSES; i++) {
        if (i > 0) mp_emit_str(buf, &pos, cap, ",");
        mp_emit_str(buf, &pos, cap, "{\"bytes\":");
        mp_emit_i64(buf, &pos, cap, size_class_bytes[i]);
        mp_emit_str(buf, &pos, cap, ",\"live\":");
        mp_emit_i64(buf, &pos, cap, live_c[i]);
        mp_emit_str(buf, &pos, cap, ",\"alloc_count\":");
        mp_emit_i64(buf, &pos, cap, acnt_c[i]);
        mp_emit_str(buf, &pos, cap, ",\"alloc_bytes\":");
        mp_emit_i64(buf, &pos, cap, abyt_c[i]);
        mp_emit_str(buf, &pos, cap, "}");
    }
    mp_emit_str(buf, &pos, cap, "],\"huge\":{\"live\":");
    mp_emit_i64(buf, &pos, cap, live_h);
    mp_emit_str(buf, &pos, cap, ",\"alloc_count\":");
    mp_emit_i64(buf, &pos, cap, acnt_h);
    mp_emit_str(buf, &pos, cap, ",\"alloc_bytes\":");
    mp_emit_i64(buf, &pos, cap, abyt_h);
    // Per-line allocation sites (line==0 = runtime-internal). Only
    // non-empty slots are emitted; stored keys are line+1. Bounded by
    // the remaining buffer (mp_emit_* truncate safely, but we stop
    // emitting entries well before the cap to keep the JSON valid).
    mp_emit_str(buf, &pos, cap, "},\"by_line\":[");
    i32 emitted = 0;
    for (i32 i = 0; i < MP_LINE_SLOTS; i++) {
        if (ln_key[i] == 0) continue;
        if (pos > cap - 256) break;   // leave room for the trailer
        if (emitted > 0) mp_emit_str(buf, &pos, cap, ",");
        mp_emit_str(buf, &pos, cap, "{\"line\":");
        mp_emit_i64(buf, &pos, cap, ln_key[i] - 1);
        mp_emit_str(buf, &pos, cap, ",\"alloc_count\":");
        mp_emit_i64(buf, &pos, cap, ln_cnt[i]);
        mp_emit_str(buf, &pos, cap, ",\"alloc_bytes\":");
        mp_emit_i64(buf, &pos, cap, ln_byt[i]);
        mp_emit_str(buf, &pos, cap, "}");
        emitted++;
    }
    mp_emit_str(buf, &pos, cap, "],\"totals\":{\"alloc_count\":");
    mp_emit_i64(buf, &pos, cap, alloc_t);
    mp_emit_str(buf, &pos, cap, ",\"free_count\":");
    mp_emit_i64(buf, &pos, cap, free_t);
    mp_emit_str(buf, &pos, cap, ",\"live_bytes\":");
    mp_emit_i64(buf, &pos, cap, livebytes);
    mp_emit_str(buf, &pos, cap, "}}\n");

    // O_WRONLY|O_CREAT|O_TRUNC = 577, mode 0644 = 420.
    i64 fd = volt_open(path_ptr, path_len, 577, 420);
    if (fd < 0) { mutex_unlock(&g_mp_dump_lock); return fd; }
    i64 w = sys_write_raw(fd, buf, pos);
    sys_close(fd);
    mutex_unlock(&g_mp_dump_lock);
    if (w < 0) return w;
    return 0;
}

// volt_memprofile_note_line stamps the calling thread's current source
// line so the next volt_alloc attributes its allocation there. Emitted
// per-statement by codegen only under `--memprofile`. Cheap: a single
// thread-local store.
void volt_memprofile_note_line(i64 line) {
    volt_tls_set_slot0(line);
}

// Memory-profile auto-dump path. Set by `volt build --memprofile <p>`
// (codegen injects a volt_runtime_memprofile_set_path call at main's
// entry). When non-empty, volt_runtime_at_program_exit dumps the
// profile just before the process exits — robust against multiple
// return points in main since it lives in the _start epilogue.
static char g_memprofile_path[4096];
static i64  g_memprofile_path_len = 0;

void volt_runtime_memprofile_set_path(const char* p, i64 n) {
    if (n < 0) n = 0;
    if (n > 4095) n = 4095;
    for (i64 i = 0; i < n; i++) g_memprofile_path[i] = p[i];
    g_memprofile_path_len = n;
    // A registered path implies the user wants profiling — turn on the
    // per-line accumulation so volt_alloc records call sites.
    g_mp_line_enabled = 1;
}

// volt_runtime_at_program_exit runs in the _start epilogue after main
// returns, before sys_exit_group. Currently: flush the memory profile
// if a path was registered. Cheap no-op otherwise. Keep this free of
// anything that could fault — it runs with the process half-torn-down.
void volt_runtime_at_program_exit(void) {
    if (g_memprofile_path_len > 0) {
        volt_runtime_memprofile_dump(g_memprofile_path, g_memprofile_path_len);
    }
}

// volt_write_n: writes up to `n` bytes from buf to fd. Returns bytes
// written, or -errno. Used by syscall.Write when the caller wants the
// byte count; log.Println uses the older void volt_write which is
// implemented in start_*.s.
i64 volt_write_n(i64 fd, const void* buf, i64 n) {
    return sys_write_raw(fd, buf, n);
}

// volt_read_all: reads all available bytes from fd into a heap buffer
// and returns the resulting %string-shaped value (ptr+len). On error
// returns a zero-init string (ptr=NULL, len=0). Caller checks ptr.
//
// SysV / AArch64 ABI: a 16-byte struct return goes back in rax+rdx
// (x0+x1 on arm64), so the LLVM %string layout {ptr, i64} maps cleanly.
typedef struct { void* ptr; i64 len; } volt_string_t;

volt_string_t volt_read_all(i64 fd) {
    volt_string_t r;
    r.ptr = 0;
    r.len = 0;
    i64 cap = 4096;
    char* buf = (char*)volt_alloc(cap);
    i64 len = 0;
    while (1) {
        if (len + 4096 > cap) {
            i64 new_cap = cap * 2;
            char* new_buf = (char*)volt_alloc(new_cap);
            for (i64 i = 0; i < len; i++) new_buf[i] = buf[i];
            buf = new_buf;
            cap = new_cap;
        }
        i64 nread = sys_read(fd, buf + len, 4096);
        if (nread < 0) {
            r.ptr = 0;
            r.len = 0;
            return r;
        }
        if (nread == 0) break;
        len += nread;
    }
    r.ptr = buf;
    r.len = len;
    return r;
}

// volt_read_line reads a single line from fd: bytes up to (and
// consuming, but not including) the next '\n', or up to EOF. Returns a
// fresh heap %string. On a terminal in canonical mode a read returns
// once the user presses Enter, so this yields exactly the typed line —
// the building block for interactive prompts. Reads one byte at a time
// so it never consumes past the newline (important for a TTY: leaves
// the rest of stdin for the next prompt). Empty line / immediate EOF
// returns "" (ptr non-null, len 0). Read error returns ptr=NULL.
volt_string_t volt_read_line(i64 fd) {
    volt_string_t r;
    r.ptr = 0;
    r.len = 0;
    i64 cap = 256;
    char* buf = (char*)volt_alloc(cap);
    i64 len = 0;
    while (1) {
        if (len + 1 > cap) {
            i64 new_cap = cap * 2;
            char* new_buf = (char*)volt_alloc(new_cap);
            for (i64 i = 0; i < len; i++) new_buf[i] = buf[i];
            buf = new_buf;
            cap = new_cap;
        }
        char c;
        i64 nread = sys_read(fd, &c, 1);
        if (nread < 0) { r.ptr = 0; r.len = 0; return r; }
        if (nread == 0) break;     // EOF
        if (c == '\n') break;      // end of line (newline consumed, not stored)
        buf[len] = c;
        len += 1;
    }
    r.ptr = buf;     // non-null even for an empty line
    r.len = len;
    return r;
}

// ---------------------------------------------------------------------
// Terminal control — backs the `term` stdlib package. All ioctl/poll
// based, no libc. termios/winsize are accessed by byte offset inside an
// 8-byte-aligned scratch buffer; the field layout below is the Linux
// asm-generic ABI, identical on x86_64 and aarch64 (both little-endian).
//
//   struct winsize  { u16 ws_row@0; u16 ws_col@2; ... }
//   struct termios  { u32 c_iflag@0; c_oflag@4; c_cflag@8; c_lflag@12;
//                     u8 c_line@16; u8 c_cc[NCCS=19]@17 }  (VMIN=6,VTIME=5)
//   struct pollfd   { int fd@0; short events@4; short revents@6 }
// ---------------------------------------------------------------------

#define TIOCGWINSZ 0x5413
#define TCGETS     0x5401
#define TCSETS     0x5402
#define T_ICANON   0x0002   // c_lflag: canonical (line) mode
#define T_ECHO     0x0008   // c_lflag: echo input
#define T_ISIG     0x0001   // c_lflag: generate signals (INTR/QUIT/SUSP)
#define T_ICRNL    0x0100   // c_iflag: translate CR -> NL on input
#define T_IXON     0x0400   // c_iflag: XON/XOFF flow control on output
#define POLLIN_BIT 0x0001

static i64 saved_termios[8];     // raw bytes of the pre-raw termios
static i32 saved_termios_ok = 0; // set once volt_term_makeraw succeeds

// volt_term_size: TIOCGWINSZ on fd. Packs the result as (rows<<16)|cols
// so a single i64 carries both. Returns 0 on failure (e.g. fd is not a
// terminal) — callers substitute a sensible default (24x80).
i64 volt_term_size(i64 fd) {
    i64 raw[8];
    char* b = (char*)raw;
    for (int i = 0; i < 8; i++) raw[i] = 0;
    i64 rc = sys_ioctl(fd, TIOCGWINSZ, b);
    if (rc < 0) return 0;
    u64 rows = *(unsigned short*)(b + 0);
    u64 cols = *(unsigned short*)(b + 2);
    return (i64)((rows << 16) | cols);
}

// volt_term_makeraw: switch fd into "cbreak" mode — ICANON/ECHO/ISIG
// off, CR translation + flow control off, VMIN=1/VTIME=0 (one byte at a
// time, blocking). Disabling ISIG means Ctrl-C arrives as byte 3 rather
// than killing the process, so a TUI can always run its restore-on-exit
// path. The prior settings are saved for volt_term_restore. Returns 0
// on success or the negative ioctl errno.
i64 volt_term_makeraw(i64 fd) {
    i64 raw[8];
    char* b = (char*)raw;
    for (int i = 0; i < 8; i++) raw[i] = 0;
    i64 rc = sys_ioctl(fd, TCGETS, b);
    if (rc < 0) return rc;
    for (int i = 0; i < 8; i++) saved_termios[i] = raw[i];
    saved_termios_ok = 1;
    unsigned int* iflag = (unsigned int*)(b + 0);
    unsigned int* lflag = (unsigned int*)(b + 12);
    *iflag = *iflag & ~(unsigned int)(T_ICRNL | T_IXON);
    *lflag = *lflag & ~(unsigned int)(T_ICANON | T_ECHO | T_ISIG);
    b[23] = 1;   // c_cc[VMIN]  = 1
    b[22] = 0;   // c_cc[VTIME] = 0
    return sys_ioctl(fd, TCSETS, b);
}

// volt_term_restore: put fd back to the settings saved by the last
// volt_term_makeraw. A no-op (returns 0) if raw mode was never entered.
i64 volt_term_restore(i64 fd) {
    if (!saved_termios_ok) return 0;
    i64 raw[8];
    for (int i = 0; i < 8; i++) raw[i] = saved_termios[i];
    return sys_ioctl(fd, TCSETS, (char*)raw);
}

// volt_read_byte: read exactly one byte from fd. Returns 0..255 on
// success, -1 on EOF (read==0), -2 on error (read<0). The primitive
// behind term.ReadKey.
i64 volt_read_byte(i64 fd) {
    unsigned char c = 0;
    i64 n = sys_read(fd, &c, 1);
    if (n < 0) return -2;
    if (n == 0) return -1;
    return (i64)c;
}

// volt_poll_in: wait up to `ms` milliseconds for fd to become readable.
// Returns 1 if readable, 0 on timeout, -1 on error. ms < 0 blocks
// indefinitely (NULL timeout). Lets a TUI loop refresh on a tick while
// still reacting immediately to a keypress.
i64 volt_poll_in(i64 fd, i64 ms) {
    i64 pfd_raw = 0;
    char* pfd = (char*)&pfd_raw;
    *(int*)(pfd + 0) = (int)fd;
    *(short*)(pfd + 4) = (short)POLLIN_BIT;
    *(short*)(pfd + 6) = 0;
    if (ms < 0) {
        i64 rc = sys_ppoll(pfd, 1, 0, 0, 8);
        if (rc < 0) return -1;
        return rc > 0 ? 1 : 0;
    }
    i64 ts[2];                       // struct timespec { sec; nsec; }
    ts[0] = ms / 1000;
    ts[1] = (ms % 1000) * 1000000;
    i64 rc = sys_ppoll(pfd, 1, (char*)ts, 0, 8);
    if (rc < 0) return -1;
    return rc > 0 ? 1 : 0;
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
    map_entry_t** buckets;    // length == num_buckets
    i64           value_kind; // 0 = plain i64 value; 1 = boxed %string value
} map_t;

// map_free_value reclaims a boxed value when the map owns it. Only
// value_kind 1 (boxed %string) is owned: the i64 value is a pointer to
// a 16-byte {char* ptr; i64 len} box whose backing was moved into the
// map at set-time. volt_str_free is heap-range-safe (no-ops on .rodata
// literal backings). value_kind 0 (plain i64 / slice box) is left
// untouched — slice value ownership is a documented follow-up.
static void map_free_value(i64 value_kind, i64 value) {
    if (value_kind != 1) return;
    if (value == 0) return;
    char** box = (char**)value;   // box[0] = backing ptr
    volt_str_free(box[0]);
    volt_free(box);
}

// map_clone_value returns an independent copy of a boxed value so a
// cloned map owns its values separately from the source (else freeing
// the clone would double-free the shared value box/backing). Only
// value_kind 1 (boxed %string) is deep-copied: a fresh 16-byte box +
// a fresh backing buffer holding the same bytes. Other kinds are
// returned as-is (shallow), matching their current ownership.
static i64 map_clone_value(i64 value_kind, i64 value) {
    if (value_kind != 1) return value;
    if (value == 0) return 0;
    char** src_box = (char**)value;
    char* src_ptr  = src_box[0];
    i64   src_len  = ((i64*)value)[1];   // box layout: {char* ptr; i64 len}
    i64 kalloc = src_len > 0 ? src_len : 1;
    char* nbacking = (char*)volt_alloc(kalloc);
    for (i64 i = 0; i < src_len; i++) nbacking[i] = src_ptr[i];
    char** nbox = (char**)volt_alloc(16);
    nbox[0] = nbacking;
    ((i64*)nbox)[1] = src_len;
    return (i64)nbox;
}

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

void* volt_map_new(i64 value_kind) {
    map_t* m = (map_t*)volt_alloc((i64)sizeof(map_t));
    m->num_buckets = MAP_INIT_BUCKETS;
    m->buckets = (map_entry_t**)volt_alloc((i64)sizeof(map_entry_t*) * MAP_INIT_BUCKETS);
    m->value_kind = value_kind;
    return m;
}

// map_maybe_grow doubles the bucket array and rehashes every entry
// into its new slot. Called from volt_map_set under the map's lock.
static void map_maybe_grow(map_t* m) {
    // Resize when load factor exceeds 0.75 (count > num_buckets * 3 / 4).
    if (m->count * 4 <= m->num_buckets * 3) return;

    i64 new_n = m->num_buckets * 2;
    map_entry_t** old_buckets = m->buckets;
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
    // Entries were relinked into new_buckets; the old pointer array is
    // now stale and was previously leaked on every resize. Reclaim it.
    volt_free(old_buckets);
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

// volt_map_delete removes the entry with the given key. Silently
// succeeds if the key is absent (matching Go's `delete(m, k)` no-op
// on missing). Buckets stay sized; only the count drops.
void volt_map_delete(void* m_, char* key_ptr, i64 key_len) {
    map_t* m = (map_t*)m_;
    if (m == 0) return;
    mutex_lock(&m->lock);
    u64 h = hash_bytes(key_ptr, key_len);
    map_entry_t** prev = &m->buckets[h % (u64)m->num_buckets];
    map_entry_t* e = *prev;
    while (e) {
        if (key_eq(e->key_ptr, e->key_len, key_ptr, key_len)) {
            *prev = e->next;
            m->count--;
            // Free the map-owned key copy, the boxed value (if owned),
            // and the entry itself.
            map_free_value(m->value_kind, e->value);
            volt_free(e->key_ptr);
            volt_free(e);
            mutex_unlock(&m->lock);
            return;
        }
        prev = &e->next;
        e = e->next;
    }
    mutex_unlock(&m->lock);
}

void volt_map_set(void* m_, char* key_ptr, i64 key_len, i64 value) {
    map_t* m = (map_t*)m_;
    mutex_lock(&m->lock);
    u64 h = hash_bytes(key_ptr, key_len);
    map_entry_t** bucket = &m->buckets[h % (u64)m->num_buckets];
    map_entry_t* e = *bucket;
    while (e) {
        if (key_eq(e->key_ptr, e->key_len, key_ptr, key_len)) {
            // Overwrite: free the OLD boxed value before replacing it,
            // else string-valued maps leak the prior value on every
            // reassignment of the same key.
            map_free_value(m->value_kind, e->value);
            e->value = value;
            mutex_unlock(&m->lock);
            return;
        }
        e = e->next;
    }
    map_entry_t* ne = (map_entry_t*)volt_alloc((i64)sizeof(map_entry_t));
    ne->next    = *bucket;
    // The map OWNS its keys: copy the caller's key bytes into a fresh
    // map-owned buffer. The caller's key (often a loop-local heap string
    // freed by A3 at scope end, or a .rodata literal) must NOT be aliased
    // — aliasing let freelist reuse corrupt the stored key. Freed in
    // volt_map_delete / volt_map_free. Empty-key (len 0) still gets a
    // 1-byte owned buffer so key_ptr is never a shared/NULL alias.
    i64 kalloc = key_len > 0 ? key_len : 1;
    char* kcopy = (char*)volt_alloc(kalloc);
    for (i64 i = 0; i < key_len; i++) kcopy[i] = key_ptr[i];
    ne->key_ptr = kcopy;
    ne->key_len = key_len;
    ne->value   = value;
    *bucket = ne;
    m->count++;
    map_maybe_grow(m);
    mutex_unlock(&m->lock);
}

// ---- String construction --------------------------------------------
// volt_string_from_bytes builds a fresh %string by heap-allocating
// `n` bytes and copying from `buf`. Used by bytes.Builder.String()
// (and any future []byte → string conversion path). The returned
// string owns its bytes; the input slice's backing buffer is
// untouched (no aliasing).
volt_string_t volt_string_from_bytes(const char* buf, i64 n) {
    volt_string_t r;
    r.ptr = 0;
    r.len = 0;
    if (n <= 0) return r;
    char* dst = (char*)volt_alloc(n);
    for (i64 i = 0; i < n; i++) dst[i] = buf[i];
    r.ptr = dst;
    r.len = n;
    return r;
}

// volt_string_concat builds a fresh %string by heap-allocating
// a_len+b_len bytes and copying both inputs in sequence. The result
// is an independently-owned string; the inputs are untouched.

volt_string_t volt_string_concat(const char* a_ptr, i64 a_len,
                                  const char* b_ptr, i64 b_len) {
    volt_string_t r;
    r.ptr = 0;
    r.len = 0;
    if (a_len < 0) a_len = 0;
    if (b_len < 0) b_len = 0;
    i64 total = a_len + b_len;
    if (total == 0) return r;
    char* buf = (char*)volt_alloc(total);
    for (i64 i = 0; i < a_len; i++) buf[i] = a_ptr[i];
    for (i64 i = 0; i < b_len; i++) buf[a_len + i] = b_ptr[i];
    r.ptr = buf;
    r.len = total;
    return r;
}

// volt_string_eq compares two strings byte-by-byte. Returns 1 if
// equal (same length AND same bytes), 0 otherwise. Used by `==` /
// `!=` for %string operands.
i64 volt_string_eq(const char* a_ptr, i64 a_len,
                    const char* b_ptr, i64 b_len) {
    if (a_len != b_len) return 0;
    for (i64 i = 0; i < a_len; i++) {
        if (a_ptr[i] != b_ptr[i]) return 0;
    }
    return 1;
}

// volt_chr_string makes a 1-byte string from byte b. Mostly useful
// for digit-by-digit construction (Itoa, etc.).
volt_string_t volt_chr_string(i64 b) {
    volt_string_t r;
    char* buf = (char*)volt_alloc(1);
    buf[0] = (char)(b & 0xff);
    r.ptr = buf;
    r.len = 1;
    return r;
}

// ---- Process args / env --------------------------------------------
// argc/argv/envp are stashed by _start (start_*.s) at process entry.
// Expose helpers that the stdlib can call to materialize volt strings.

extern i64    volt_argc;
extern char** volt_argv;
extern char** volt_envp;

static i64 cstr_len(const char* s) {
    if (s == 0) return 0;
    i64 n = 0;
    while (s[n] != 0) n++;
    return n;
}

// volt_arg_count(): number of CLI arguments (including argv[0]).
i64 volt_arg_count(void) { return volt_argc; }

// volt_arg_at(i): returns a {ptr, len} pointing INTO argv[i]'s storage.
// The bytes live for the process lifetime (kernel-provided), so callers
// can keep the string indefinitely without copying.
volt_string_t volt_arg_at(i64 i) {
    volt_string_t r;
    r.ptr = 0;
    r.len = 0;
    if (i < 0 || i >= volt_argc) return r;
    char* p = volt_argv[i];
    r.ptr = p;
    r.len = cstr_len(p);
    return r;
}

// volt_env_get(name_ptr, name_len): scan envp for "name=value"; return
// the value as a volt_string_t, or {NULL, 0} if not found.
volt_string_t volt_env_get(const char* name_ptr, i64 name_len) {
    volt_string_t r;
    r.ptr = 0;
    r.len = 0;
    if (volt_envp == 0) return r;
    for (i64 i = 0; volt_envp[i] != 0; i++) {
        char* entry = volt_envp[i];
        // Match name followed by '='.
        i64 j;
        int ok = 1;
        for (j = 0; j < name_len; j++) {
            if (entry[j] == 0 || entry[j] != name_ptr[j]) {
                ok = 0;
                break;
            }
        }
        if (!ok) continue;
        if (entry[j] != '=') continue;
        r.ptr = entry + j + 1;
        r.len = cstr_len(entry + j + 1);
        return r;
    }
    return r;
}

// ---------------------------------------------------------------------
// Process execution — raw fork/exec/wait/pipe syscall helpers (no libc),
// used by volt_exec (the `exec` package engine). The child is created
// with clone(SIGCHLD) (== fork; aarch64 has no raw fork). Between clone
// and execve the child touches NOTHING that could take a lock (no
// volt_alloc): argv/env/path buffers are built on the parent stack and
// COW-inherited.
// ---------------------------------------------------------------------

// sys_clone_fork: clone(SIGCHLD, stack=0, ...) — fork semantics on both
// arches. Returns the child pid in the parent, 0 in the child, -errno
// on failure. With all pointer args 0 the per-arch clone arg-order
// difference (CLONE_BACKWARDS on aarch64) is irrelevant.
#if defined(__x86_64__)
static i64 sys_clone_fork(void) {
    register i64 rax __asm__("rax") = SYS_CLONE;
    register i64 rdi __asm__("rdi") = 17;   // SIGCHLD
    register i64 rsi __asm__("rsi") = 0;    // child stack (0 = share via COW)
    register i64 rdx __asm__("rdx") = 0;    // parent_tid
    register i64 r10 __asm__("r10") = 0;    // child_tid
    register i64 r8  __asm__("r8")  = 0;    // tls
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10), "r"(r8)
        : "rcx", "r11", "memory");
    return rax;
}
static i64 sys_execve(const char* path, char* const argv[], char* const envp[]) {
    register i64 rax __asm__("rax") = SYS_EXECVE;
    register i64 rdi __asm__("rdi") = (i64)path;
    register i64 rsi __asm__("rsi") = (i64)argv;
    register i64 rdx __asm__("rdx") = (i64)envp;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx)
        : "rcx", "r11", "memory");
    return rax;
}
static i64 sys_wait4(i64 pid, i32* status, i64 options, void* ru) {
    register i64 rax __asm__("rax") = SYS_WAIT4;
    register i64 rdi __asm__("rdi") = pid;
    register i64 rsi __asm__("rsi") = (i64)status;
    register i64 rdx __asm__("rdx") = options;
    register i64 r10 __asm__("r10") = (i64)ru;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10)
        : "rcx", "r11", "memory");
    return rax;
}
static i64 sys_pipe2(i32* fds, i64 flags) {
    register i64 rax __asm__("rax") = SYS_PIPE2;
    register i64 rdi __asm__("rdi") = (i64)fds;
    register i64 rsi __asm__("rsi") = flags;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi)
        : "rcx", "r11", "memory");
    return rax;
}
static i64 sys_dup3(i64 oldfd, i64 newfd, i64 flags) {
    register i64 rax __asm__("rax") = SYS_DUP3;
    register i64 rdi __asm__("rdi") = oldfd;
    register i64 rsi __asm__("rsi") = newfd;
    register i64 rdx __asm__("rdx") = flags;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx)
        : "rcx", "r11", "memory");
    return rax;
}
static i64 sys_chdir(const char* path) {
    register i64 rax __asm__("rax") = SYS_CHDIR;
    register i64 rdi __asm__("rdi") = (i64)path;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi)
        : "rcx", "r11", "memory");
    return rax;
}
static void sys_exit_raw(i64 code) {
    register i64 rax __asm__("rax") = SYS_EXIT;
    register i64 rdi __asm__("rdi") = code;
    __asm__ volatile("syscall" : : "r"(rax), "r"(rdi) : "memory");
    __builtin_unreachable();
}
#elif defined(__aarch64__)
static i64 sys_clone_fork(void) {
    register i64 x8 __asm__("x8") = SYS_CLONE;
    register i64 x0 __asm__("x0") = 17;   // SIGCHLD
    register i64 x1 __asm__("x1") = 0;
    register i64 x2 __asm__("x2") = 0;
    register i64 x3 __asm__("x3") = 0;
    register i64 x4 __asm__("x4") = 0;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2), "r"(x3), "r"(x4)
        : "memory");
    return x0;
}
static i64 sys_execve(const char* path, char* const argv[], char* const envp[]) {
    register i64 x8 __asm__("x8") = SYS_EXECVE;
    register i64 x0 __asm__("x0") = (i64)path;
    register i64 x1 __asm__("x1") = (i64)argv;
    register i64 x2 __asm__("x2") = (i64)envp;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2)
        : "memory");
    return x0;
}
static i64 sys_wait4(i64 pid, i32* status, i64 options, void* ru) {
    register i64 x8 __asm__("x8") = SYS_WAIT4;
    register i64 x0 __asm__("x0") = pid;
    register i64 x1 __asm__("x1") = (i64)status;
    register i64 x2 __asm__("x2") = options;
    register i64 x3 __asm__("x3") = (i64)ru;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2), "r"(x3)
        : "memory");
    return x0;
}
static i64 sys_pipe2(i32* fds, i64 flags) {
    register i64 x8 __asm__("x8") = SYS_PIPE2;
    register i64 x0 __asm__("x0") = (i64)fds;
    register i64 x1 __asm__("x1") = flags;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1)
        : "memory");
    return x0;
}
static i64 sys_dup3(i64 oldfd, i64 newfd, i64 flags) {
    register i64 x8 __asm__("x8") = SYS_DUP3;
    register i64 x0 __asm__("x0") = oldfd;
    register i64 x1 __asm__("x1") = newfd;
    register i64 x2 __asm__("x2") = flags;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1), "r"(x2)
        : "memory");
    return x0;
}
static i64 sys_chdir(const char* path) {
    register i64 x8 __asm__("x8") = SYS_CHDIR;
    register i64 x0 __asm__("x0") = (i64)path;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8)
        : "memory");
    return x0;
}
static void sys_exit_raw(i64 code) {
    register i64 x8 __asm__("x8") = SYS_EXIT;
    register i64 x0 __asm__("x0") = code;
    __asm__ volatile("svc #0" : : "r"(x8), "r"(x0) : "memory");
    __builtin_unreachable();
}
#endif

// wait_exit_code maps a wait4 status word to a conventional exit code:
// normal exit → the child's code (0-255); killed by signal → 128 + sig.
static i64 wait_exit_code(i32 status) {
    if ((status & 0x7f) == 0) return (status >> 8) & 0xff;  // WIFEXITED
    return 128 + (status & 0x7f);                            // WTERMSIG
}

// ---------------------------------------------------------------------
// exec spawn support: no-shell, argv-based process launch backing the
// `exec` stdlib package (a port of Go's os/exec). The single core is
// volt_proc_spawn_fds (below): it execve's `path` directly with a literal
// argv — no /bin/sh, no quoting/injection — optionally chdir's, replaces
// the environment, dup3's the child's 0/1/2 to caller-supplied fds (-1 =
// inherit), and returns the child pid; the volt-level helpers reap with
// volt_exec_wait. Like volt_proc_*, the child touches nothing that could
// take a lock between clone and execve — every C string is built on the
// parent stack and COW-inherited. The shared argv/env packer
// (volt_exec_pack) and size limits live here.
// ---------------------------------------------------------------------

#define VOLT_EXEC_NMAX     1024     // max argv / env entries
#define VOLT_EXEC_ARGBYTES 65536    // scratch bytes for argv (and, separately, env)

// volt_exec_pack copies `n` volt strings into `bytes` as NUL-terminated
// C strings and fills `cv` (a NULL-terminated char* array). Returns 1 on
// success, 0 on overflow (too many entries / not enough scratch).
static int volt_exec_pack(volt_string_t* v, i64 n, char* bytes, i64 bytescap, char** cv, i64 cvmax) {
    if (n < 0 || n > cvmax) return 0;
    i64 off = 0;
    for (i64 i = 0; i < n; i++) {
        i64 m = v[i].len;
        if (m < 0 || off + m + 1 > bytescap) return 0;
        const char* s = (const char*)v[i].ptr;
        for (i64 j = 0; j < m; j++) bytes[off + j] = s[j];
        bytes[off + m] = 0;
        cv[i] = &bytes[off];
        off += m + 1;
    }
    cv[n] = 0;
    return 1;
}

// volt_exec_wait reaps `pid` and returns its exit code (128+sig if killed,
// -1 if wait4 failed). Blocking.
i64 volt_exec_wait(i64 pid) {
    i32 status = 0;
    if (sys_wait4(pid, &status, 0, 0) < 0) return -1;
    return wait_exit_code(status);
}

// sys_kill / sys_getpid: signal delivery + the caller's own pid, backing
// Process.Stop / Process.Kill / Process.PPID.
#if defined(__x86_64__)
static i64 sys_kill(i64 pid, i64 sig) {
    register i64 rax __asm__("rax") = SYS_KILL;
    register i64 rdi __asm__("rdi") = pid;
    register i64 rsi __asm__("rsi") = sig;
    __asm__ volatile("syscall" : "+r"(rax) : "r"(rdi), "r"(rsi) : "rcx", "r11", "memory");
    return rax;
}
static i64 sys_getpid(void) {
    register i64 rax __asm__("rax") = SYS_GETPID;
    __asm__ volatile("syscall" : "+r"(rax) : : "rcx", "r11", "memory");
    return rax;
}
#elif defined(__aarch64__)
static i64 sys_kill(i64 pid, i64 sig) {
    register i64 x8 __asm__("x8") = SYS_KILL;
    register i64 x0 __asm__("x0") = pid;
    register i64 x1 __asm__("x1") = sig;
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x8), "r"(x1) : "memory");
    return x0;
}
static i64 sys_getpid(void) {
    register i64 x8 __asm__("x8") = SYS_GETPID;
    register i64 x0 __asm__("x0");
    __asm__ volatile("svc #0" : "=r"(x0) : "r"(x8) : "memory");
    return x0;
}
#endif

// volt_kill sends signal `sig` to `pid` (SIGTERM=15 / SIGKILL=9); returns 0
// or a negative errno. volt_getpid returns the caller's pid (a child's
// parent is us → Process.PPID). volt_gettid returns the caller's kernel
// thread id — unique per OS thread, used for collision-free temp names.
i64 volt_kill(i64 pid, i64 sig) { return sys_kill(pid, sig); }
i64 volt_getpid(void) { return sys_getpid(); }
i64 volt_gettid(void) {
#if defined(__x86_64__)
    register i64 rax __asm__("rax") = SYS_GETTID;
    __asm__ volatile("syscall" : "+r"(rax) : : "rcx", "r11", "memory");
    return rax;
#elif defined(__aarch64__)
    register i64 x8 __asm__("x8") = SYS_GETTID;
    register i64 x0 __asm__("x0") = 0;
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x8) : "memory");
    return x0;
#endif
}

// volt_proc_spawn_fds forks+execs `path` (no shell), wiring the child's
// stdin/stdout/stderr to the given fds via dup3 — pass -1 for a stream to
// leave it inherited (the parent's). No pipes, no pumping: the child does
// I/O directly on the fds. Returns the child pid, or -1 on failure. Backs
// exec.Cmd.Spawn (all -1) and SpawnWithStreams (real fds, e.g. files).
i64 volt_proc_spawn_fds(char* path_ptr, i64 path_len,
                        volt_string_t* argv, i64 argc,
                        volt_string_t* env,  i64 envc,
                        char* dir_ptr, i64 dir_len,
                        i64 in_fd, i64 out_fd, i64 err_fd) {
    if (path_len < 0 || path_len >= 4096) return -1;
    char pathbuf[4096];
    for (i64 i = 0; i < path_len; i++) pathbuf[i] = path_ptr[i];
    pathbuf[path_len] = 0;

    char dirbuf[4096];
    int have_dir = (dir_len > 0);
    if (have_dir) {
        if (dir_len >= 4096) return -1;
        for (i64 i = 0; i < dir_len; i++) dirbuf[i] = dir_ptr[i];
        dirbuf[dir_len] = 0;
    }

    char  argbytes[VOLT_EXEC_ARGBYTES];
    char* cargv[VOLT_EXEC_NMAX + 1];
    char* fallback_argv[2];
    char** cargv_final;
    if (argc <= 0) {
        fallback_argv[0] = pathbuf; fallback_argv[1] = 0;
        cargv_final = fallback_argv;
    } else {
        if (!volt_exec_pack(argv, argc, argbytes, sizeof argbytes, cargv, VOLT_EXEC_NMAX)) return -1;
        cargv_final = cargv;
    }

    char  envbytes[VOLT_EXEC_ARGBYTES];
    char* cenvarr[VOLT_EXEC_NMAX + 1];
    char** cenv;
    if (envc > 0) {
        if (!volt_exec_pack(env, envc, envbytes, sizeof envbytes, cenvarr, VOLT_EXEC_NMAX)) return -1;
        cenv = cenvarr;
    } else {
        cenv = volt_envp;
    }

    i64 pid = sys_clone_fork();
    if (pid < 0) return -1;
    if (pid == 0) {
        if (have_dir) { if (sys_chdir(dirbuf) < 0) sys_exit_raw(127); }
        i64 dfl[4]; dfl[0] = 0; dfl[1] = 0; dfl[2] = 0; dfl[3] = 0;
        sys_rt_sigaction(13, dfl, 0, 8);   // restore child's default SIGPIPE
        // Redirect each stream whose fd was supplied (skip when it already
        // sits at the target — dup3 of equal fds is EINVAL).
        if (in_fd  >= 0 && in_fd  != 0) sys_dup3(in_fd,  0, 0);
        if (out_fd >= 0 && out_fd != 1) sys_dup3(out_fd, 1, 0);
        if (err_fd >= 0 && err_fd != 2) sys_dup3(err_fd, 2, 0);
        sys_execve(pathbuf, cargv_final, cenv);
        sys_exit_raw(127);
    }
    return pid;
}

// volt_read_some does a SINGLE read of up to `max` bytes from `fd` into a
// fresh heap buffer, returning whatever that one read yielded. len 0 ⇒
// EOF (or error). Unlike volt_read_all (which loops to EOF), this is the
// primitive for streaming a pipe incrementally.
volt_string_t volt_read_some(i64 fd, i64 max) {
    volt_string_t r; r.ptr = 0; r.len = 0;
    if (max <= 0) return r;
    char* buf = (char*)volt_alloc(max);
    i64 n = sys_read(fd, buf, max);
    if (n <= 0) {           // EOF or error → empty string; return the
        volt_free(buf);     // freshly-allocated buffer to the pool rather
        return r;           // than orphaning it (every read ends in one
    }                       // such EOF call, so this dominated exec leaks).
    r.ptr = buf;
    r.len = n;
    return r;
}

// ---- Clock / time ---------------------------------------------------
// volt_now_ns(): nanoseconds since the Unix epoch (CLOCK_REALTIME via
// sys_clock_gettime). Used by `time.Now()` in the stdlib.

typedef struct { i64 sec; i64 nsec; } volt_timespec_t;

#if defined(__x86_64__)
static i64 sys_clock_gettime(i64 clk, volt_timespec_t* ts) {
    register i64 rax __asm__("rax") = SYS_CLOCK_GETTIME;
    register i64 rdi __asm__("rdi") = clk;
    register i64 rsi __asm__("rsi") = (i64)ts;
    __asm__ volatile("syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi)
        : "rcx", "r11", "memory");
    return rax;
}
#elif defined(__aarch64__)
static i64 sys_clock_gettime(i64 clk, volt_timespec_t* ts) {
    register i64 x8 __asm__("x8") = SYS_CLOCK_GETTIME;
    register i64 x0 __asm__("x0") = clk;
    register i64 x1 __asm__("x1") = (i64)ts;
    __asm__ volatile("svc #0"
        : "+r"(x0)
        : "r"(x8), "r"(x1)
        : "memory");
    return x0;
}
#endif

i64 volt_now_ns(void) {
    volt_timespec_t ts;
    ts.sec = 0;
    ts.nsec = 0;
    sys_clock_gettime(CLOCK_REALTIME, &ts);
    return ts.sec * 1000000000 + ts.nsec;
}

i64 volt_mono_ns(void) {
    volt_timespec_t ts;
    ts.sec = 0;
    ts.nsec = 0;
    sys_clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.sec * 1000000000 + ts.nsec;
}

// ---- map iteration --------------------------------------------------
// Iterator state walks bucket-by-bucket, entry-chain-by-entry-chain.
// NOT lock-safe — mutating the map during iteration is UB (same as Go).

typedef struct {
    map_t*       m;
    i64          bucket_idx;
    map_entry_t* curr;
} map_iter_t;

void* volt_map_iter_new(void* m_) {
    map_iter_t* it = (map_iter_t*)volt_alloc((i64)sizeof(map_iter_t));
    it->m = (map_t*)m_;
    it->bucket_idx = 0;
    it->curr = 0;
    return it;
}

// Returns 1 if a next entry was produced (filling out_key_ptr/len/val);
// 0 if iteration is done. Concurrent mutation is unsafe by design.
i64 volt_map_iter_next(void* it_, char** out_key_ptr, i64* out_key_len, i64* out_val) {
    map_iter_t* it = (map_iter_t*)it_;
    map_t* m = it->m;
    if (m == 0) return 0;

    if (it->curr) {
        it->curr = it->curr->next;
    }
    while (!it->curr && it->bucket_idx < m->num_buckets) {
        it->curr = m->buckets[it->bucket_idx];
        it->bucket_idx++;
    }
    if (!it->curr) return 0;

    *out_key_ptr = it->curr->key_ptr;
    *out_key_len = it->curr->key_len;
    *out_val     = it->curr->value;
    return 1;
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
// `src`. Keys are DEEP-COPIED so the clone owns its own key buffers —
// required since the map now owns + frees its keys (volt_map_set /
// _delete / _free); aliasing the source's keys here would double-free
// each key when both maps are dropped. Kind-1 (boxed %string) VALUES are
// likewise DEEP-COPIED via map_clone_value so the clone owns independent
// value backings (else freeing both maps would double-free the shared
// backing). Other value kinds (slice boxes) stay shallow — slice value
// ownership is a documented follow-up.
void* volt_map_clone(void* src_) {
    if (src_ == 0) return (void*)0;
    map_t* src = (map_t*)src_;
    map_t* dst = (map_t*)volt_alloc((i64)sizeof(map_t));
    mutex_lock(&src->lock);
    dst->num_buckets = src->num_buckets;
    dst->buckets = (map_entry_t**)volt_alloc((i64)sizeof(map_entry_t*) * dst->num_buckets);
    dst->value_kind = src->value_kind;
    for (i64 i = 0; i < src->num_buckets; i++) {
        for (map_entry_t* e = src->buckets[i]; e != 0; e = e->next) {
            map_entry_t* ne = (map_entry_t*)volt_alloc((i64)sizeof(map_entry_t));
            ne->next    = dst->buckets[i];
            // Deep-copy the key: the clone owns an independent buffer.
            i64 kalloc = e->key_len > 0 ? e->key_len : 1;
            char* kc = (char*)volt_alloc(kalloc);
            for (i64 j = 0; j < e->key_len; j++) kc[j] = e->key_ptr[j];
            ne->key_ptr = kc;
            ne->key_len = e->key_len;
            // Deep-copy boxed values too (kind 1) so the clone owns them
            // independently — otherwise freeing both maps double-frees.
            ne->value   = map_clone_value(src->value_kind, e->value);
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

// volt_int_to_string builds the decimal representation of `n` as a
// fresh heap %string. Returns {ptr, len}; same layout that LLVM
// %string maps to.
volt_string_t volt_int_to_string(i64 n) {
    char tmp[24];
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
    i64 total = tlen + (neg ? 1 : 0);
    char* out = (char*)volt_alloc(total);
    i64 pos = 0;
    if (neg) out[pos++] = '-';
    while (tlen > 0) {
        out[pos++] = tmp[--tlen];
    }
    volt_string_t r;
    r.ptr = out;
    r.len = total;
    return r;
}

// volt_bool_to_string returns "true" or "false" as a heap-allocated
// %string. The 5/4-byte buffers are freshly allocated so the caller
// can hold the result indefinitely.
volt_string_t volt_bool_to_string(i64 b) {
    volt_string_t r;
    if (b) {
        char* buf = (char*)volt_alloc(4);
        buf[0] = 't'; buf[1] = 'r'; buf[2] = 'u'; buf[3] = 'e';
        r.ptr = buf;
        r.len = 4;
    } else {
        char* buf = (char*)volt_alloc(5);
        buf[0] = 'f'; buf[1] = 'a'; buf[2] = 'l'; buf[3] = 's'; buf[4] = 'e';
        r.ptr = buf;
        r.len = 5;
    }
    return r;
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

// ---- condvar -------------------------------------------------------
// User-facing condition variable. Built on the runtime cond_t + the
// user-provided mutex T. Wait(m) atomically unlocks m, sleeps until
// signaled, then reacquires m before returning — the standard
// pthread_cond_wait semantics. Signal wakes one waiter; Broadcast
// wakes all. The condvar's storage is just a cond_t (4 bytes); we
// box it in a fresh volt_alloc so the handle is a stable ptr that
// can be moved across threads like any other reference primitive.

void* volt_cond_new(void) {
    cond_t* c = (cond_t*)volt_alloc((i64)sizeof(cond_t));
    c->seq = 0;
    return c;
}

// volt_cond_wait expects `m_` to be a sync_mutex_t* (the same handle
// that volt_mutex_new returned). It accesses m->lock directly — same
// layout as volt_mutex_lock/unlock. Caller MUST hold the lock; on
// return the lock is held again. Spurious wakeups are possible per
// the futex contract; callers should re-check the predicate.
void volt_cond_wait(void* c_, void* m_) {
    cond_t* c = (cond_t*)c_;
    sync_mutex_t* m = (sync_mutex_t*)m_;
    cond_wait(c, &m->lock);
}

void volt_cond_signal(void* c_) {
    cond_signal((cond_t*)c_);
}

void volt_cond_broadcast(void* c_) {
    cond_broadcast((cond_t*)c_);
}

// ---------------------------------------------------------------------
// D.1: happens-before race detector.
//
// Public API (codegen emits these when `-race` is on):
//   volt_race_enable()           — turn on globally (called from main).
//                                  Per-thread slots are created on demand
//                                  at the first instrumented access.
//   volt_race_read (ptr, size)   — instrumented load barrier.
//   volt_race_write(ptr, size)   — instrumented store barrier.
//   volt_race_acquire(ptr)       — sync-acquire (chan recv / mutex Lock /
//                                  atomic Read). Merges the published
//                                  vector clock for ptr into mine.
//   volt_race_release(ptr)       — sync-release (chan send / mutex Unlock /
//                                  atomic Write). Bumps my clock and
//                                  publishes my vector clock at ptr.
//
// Algorithm: per-thread vector clocks of fixed width VOLT_RACE_MAX_THREADS.
// Each thread holds a kernel tid → dense-slot mapping. Sync locations
// (chan/mutex/atomic handles) hold a published vector clock; memory
// locations hold {last-writer slot, last-writer epoch, last-reader slot,
// last-reader epoch}. A read races with a prior write iff the prior
// write's epoch is NOT visible in my view (clk[wslot] < write_epoch).
// A write races with the prior reader too. False negatives are possible
// when a single slot loses precision (we keep only the most-recent
// read), but every reported race is real.
//
// All data structures are striped-mutex hash tables — slow but correct.
// The detector is OFF by default; the `-race` flag turns it on by
// emitting a volt_race_enable() at the head of main.

#define VOLT_RACE_MAX_THREADS  64
#define VOLT_RACE_SYNC_BUCKETS 1024
#define VOLT_RACE_SYNC_STRIPES   16
#define VOLT_RACE_MEM_BUCKETS  16384
#define VOLT_RACE_MEM_STRIPES    64

typedef struct race_vclock {
    i64 c[VOLT_RACE_MAX_THREADS];
} race_vclock_t;

typedef struct race_thread {
    i32 used;
    i64 ktid;
    race_vclock_t clk;   // my current view; clk[my slot] is my own epoch
} race_thread_t;

typedef struct race_sync_entry {
    i64 addr;
    race_vclock_t clk;
    struct race_sync_entry* next;
} race_sync_entry_t;

typedef struct race_mem_entry {
    i64 addr;
    i32 wslot, rslot;
    i64 wepoch, repoch;
    // Pass 752 DWARF-style race report: record the source line of the
    // last writer/reader so the race report can cite where each side
    // touched the location. 0 means unknown (e.g. write happened
    // inside a runtime helper that didn't pass a line).
    i64 wline, rline;
    struct race_mem_entry* next;
} race_mem_entry_t;

static i32             g_race_enabled        = 0;
static race_thread_t   g_race_threads[VOLT_RACE_MAX_THREADS];
static i32             g_race_thread_count   = 0;
// Pass 753 polish: count detected races so user code can assert
// race-freedom in tests via runtime.RaceViolations(). Bumped from
// race_report; cleared by volt_race_reset_violations.
static i64             g_race_violations     = 0;
static mutex_t         g_race_thread_lock    = {0};

static race_sync_entry_t* g_race_sync[VOLT_RACE_SYNC_BUCKETS];
static mutex_t            g_race_sync_lock[VOLT_RACE_SYNC_STRIPES];

static race_mem_entry_t*  g_race_mem[VOLT_RACE_MEM_BUCKETS];
static mutex_t            g_race_mem_lock[VOLT_RACE_MEM_STRIPES];

static i64 race_sys_gettid(void) {
#if defined(__x86_64__)
    register i64 rax __asm__("rax") = SYS_GETTID;
    __asm__ volatile("syscall" : "+r"(rax) : : "rcx", "r11", "memory");
    return rax;
#elif defined(__aarch64__)
    register i64 x8 __asm__("x8") = SYS_GETTID;
    register i64 x0 __asm__("x0") = 0;
    __asm__ volatile("svc #0" : "+r"(x0) : "r"(x8) : "memory");
    return x0;
#endif
}

// Returns the dense slot for the calling OS thread, registering it on
// first call. Returns -1 if the thread table is full (silent loss of
// precision — better than crashing).
static i32 race_current_slot(void) {
    i64 ktid = race_sys_gettid();
    // Optimistic read-only scan first.
    i32 n = __atomic_load_n(&g_race_thread_count, __ATOMIC_ACQUIRE);
    for (i32 i = 0; i < n; i++) {
        if (g_race_threads[i].used && g_race_threads[i].ktid == ktid) {
            return i;
        }
    }
    // Need to register.
    mutex_lock(&g_race_thread_lock);
    n = g_race_thread_count;
    for (i32 i = 0; i < n; i++) {
        if (g_race_threads[i].used && g_race_threads[i].ktid == ktid) {
            mutex_unlock(&g_race_thread_lock);
            return i;
        }
    }
    if (n >= VOLT_RACE_MAX_THREADS) {
        mutex_unlock(&g_race_thread_lock);
        return -1;
    }
    g_race_threads[n].ktid = ktid;
    for (i32 i = 0; i < VOLT_RACE_MAX_THREADS; i++) g_race_threads[n].clk.c[i] = 0;
    g_race_threads[n].clk.c[n] = 1;  // start at epoch 1
    __atomic_store_n(&g_race_threads[n].used, 1, __ATOMIC_RELEASE);
    __atomic_store_n(&g_race_thread_count, n + 1, __ATOMIC_RELEASE);
    mutex_unlock(&g_race_thread_lock);
    return n;
}

// Hash a 64-bit address. We mostly want to strip the low alignment bits
// and spread the rest. Knuth's multiplicative is good enough.
static i64 race_hash_addr(i64 a) {
    u64 x = (u64)(a >> 3);
    x *= 0x9E3779B97F4A7C15ULL;
    x ^= x >> 27;
    return (i64)x;
}

// Write a non-negative i64 into buf as decimal. Returns # bytes written.
static i32 race_fmt_i64(char* buf, i64 v) {
    if (v < 0) v = 0;
    if (v == 0) { buf[0] = '0'; return 1; }
    char tmp[24];
    i32 n = 0;
    while (v > 0 && n < 24) { tmp[n++] = (char)('0' + v % 10); v /= 10; }
    for (i32 i = 0; i < n; i++) buf[i] = tmp[n - 1 - i];
    return n;
}

// Reports a race to stderr (fd=2). Format:
//   "WARNING: DATA RACE (<kind>)\n  addr=0x<addr> t<a>@e<ae>:line<al> vs t<b>@e<be>:line<bl>\n"
// The :lineN suffix is omitted when the line is 0 (unknown). Never aborts.
static void race_report(const char* kind, i64 addr,
                        i32 aslot, i64 aepoch, i64 aline,
                        i32 bslot, i64 bepoch, i64 bline) {
    char buf[256];
    i32 i = 0;
    const char* w = "WARNING: DATA RACE (";
    while (*w) buf[i++] = *w++;
    w = kind;
    while (*w) buf[i++] = *w++;
    buf[i++] = ')'; buf[i++] = '\n';
    const char* tag = "  addr=0x";
    w = tag; while (*w) buf[i++] = *w++;
    for (i32 sh = 60; sh >= 0; sh -= 4) {
        i64 d = (addr >> sh) & 0xf;
        buf[i++] = (char)(d < 10 ? '0' + d : 'a' + (d - 10));
    }
    buf[i++] = ' '; buf[i++] = 't';
    i += race_fmt_i64(buf + i, aslot);
    buf[i++] = '@'; buf[i++] = 'e';
    i += race_fmt_i64(buf + i, aepoch);
    if (aline > 0) {
        const char* lt = ":line"; w = lt; while (*w) buf[i++] = *w++;
        i += race_fmt_i64(buf + i, aline);
    }
    buf[i++] = ' '; buf[i++] = 'v'; buf[i++] = 's'; buf[i++] = ' ';
    buf[i++] = 't';
    i += race_fmt_i64(buf + i, bslot);
    buf[i++] = '@'; buf[i++] = 'e';
    i += race_fmt_i64(buf + i, bepoch);
    if (bline > 0) {
        const char* lt = ":line"; w = lt; while (*w) buf[i++] = *w++;
        i += race_fmt_i64(buf + i, bline);
    }
    buf[i++] = '\n';
    sys_write_raw(2, buf, i);
    __atomic_add_fetch(&g_race_violations, 1, __ATOMIC_RELAXED);
}

// volt_race_violations returns the cumulative count of races detected
// since program start (or the last volt_race_reset_violations call).
// Surfaced to volt code via runtime.RaceViolations() — useful in
// tests that want to assert race-freedom or count expected races.
i64 volt_race_violations(void) {
    return (i64)__atomic_load_n(&g_race_violations, __ATOMIC_ACQUIRE);
}

void volt_race_reset_violations(void) {
    __atomic_store_n(&g_race_violations, 0, __ATOMIC_RELEASE);
}

// volt_race_enable is called ONCE from main when `-race` is set.
// Subsequent reads of g_race_enabled use __ATOMIC_RELAXED — there's
// no need for an acquire fence because (1) the value never decreases
// (set 0→1 once, then stable forever), (2) the call happens before
// any threads spawn via `run`, so thread creation itself provides the
// happens-before edge, and (3) the early-exit is on the hot path of
// every chan/mutex op even when -race is OFF — relaxing removes a
// memory fence per call on weak-memory archs (arm64). Pass 755 perf.
void volt_race_enable(void) {
    __atomic_store_n(&g_race_enabled, 1, __ATOMIC_RELEASE);
    (void)race_current_slot();  // register main thread
}

// volt_runtime_thread_count surfaces the race-detector's registered
// thread count to user code via runtime.ThreadCount(). Without -race
// the detector is inert and the count stays 0 — the runtime doesn't
// track threads globally otherwise.
i64 volt_runtime_thread_count(void) {
    return (i64)__atomic_load_n(&g_race_thread_count, __ATOMIC_ACQUIRE);
}

void volt_race_acquire(void* ptr) {
    if (!__atomic_load_n(&g_race_enabled, __ATOMIC_RELAXED)) return;
    i32 me = race_current_slot();
    if (me < 0) return;
    i64 a = (i64)ptr;
    i64 h = race_hash_addr(a);
    i64 bi = h & (VOLT_RACE_SYNC_BUCKETS - 1);
    i64 si = h & (VOLT_RACE_SYNC_STRIPES - 1);
    mutex_lock(&g_race_sync_lock[si]);
    race_sync_entry_t* e = g_race_sync[bi];
    while (e && e->addr != a) e = e->next;
    if (e) {
        // Merge e->clk into mine. Iterate only over registered slots —
        // unregistered slots have clock 0 on both sides and contribute
        // nothing. Pass 752: this caps the per-merge cost at the
        // currently-active thread count rather than the fixed
        // VOLT_RACE_MAX_THREADS ceiling (matters when the program
        // uses just a handful of threads but the detector is on).
        i32 n = __atomic_load_n(&g_race_thread_count, __ATOMIC_ACQUIRE);
        for (i32 i = 0; i < n; i++) {
            if (e->clk.c[i] > g_race_threads[me].clk.c[i]) {
                g_race_threads[me].clk.c[i] = e->clk.c[i];
            }
        }
    }
    mutex_unlock(&g_race_sync_lock[si]);
}

void volt_race_release(void* ptr) {
    if (!__atomic_load_n(&g_race_enabled, __ATOMIC_RELAXED)) return;
    i32 me = race_current_slot();
    if (me < 0) return;
    // Bump my own epoch.
    g_race_threads[me].clk.c[me]++;
    i64 a = (i64)ptr;
    i64 h = race_hash_addr(a);
    i64 bi = h & (VOLT_RACE_SYNC_BUCKETS - 1);
    i64 si = h & (VOLT_RACE_SYNC_STRIPES - 1);
    mutex_lock(&g_race_sync_lock[si]);
    race_sync_entry_t* e = g_race_sync[bi];
    while (e && e->addr != a) e = e->next;
    if (!e) {
        e = (race_sync_entry_t*)volt_alloc(sizeof(race_sync_entry_t));
        e->addr = a;
        e->next = g_race_sync[bi];
        g_race_sync[bi] = e;
    }
    // Take element-wise max of my clock and existing published clock.
    // Same registered-slot cap as the acquire merge above.
    i32 n = __atomic_load_n(&g_race_thread_count, __ATOMIC_ACQUIRE);
    for (i32 i = 0; i < n; i++) {
        if (g_race_threads[me].clk.c[i] > e->clk.c[i]) {
            e->clk.c[i] = g_race_threads[me].clk.c[i];
        }
    }
    mutex_unlock(&g_race_sync_lock[si]);
}

static race_mem_entry_t* race_mem_get_or_create(i64 addr, i64 bi, i64 si) {
    race_mem_entry_t* e = g_race_mem[bi];
    while (e && e->addr != addr) e = e->next;
    if (!e) {
        e = (race_mem_entry_t*)volt_alloc(sizeof(race_mem_entry_t));
        e->addr = addr;
        e->wslot = -1; e->rslot = -1;
        e->wepoch = 0; e->repoch = 0;
        e->wline = 0; e->rline = 0;
        e->next = g_race_mem[bi];
        g_race_mem[bi] = e;
    }
    (void)si;
    return e;
}

void volt_race_read(void* ptr, i64 size, i64 line) {
    if (!__atomic_load_n(&g_race_enabled, __ATOMIC_RELAXED)) return;
    if (size <= 0) return;
    i32 me = race_current_slot();
    if (me < 0) return;
    i64 a = (i64)ptr;
    i64 h = race_hash_addr(a);
    i64 bi = h & (VOLT_RACE_MEM_BUCKETS - 1);
    i64 si = h & (VOLT_RACE_MEM_STRIPES - 1);
    mutex_lock(&g_race_mem_lock[si]);
    race_mem_entry_t* e = race_mem_get_or_create(a, bi, si);
    // Race iff a prior writer's epoch isn't visible in my view.
    if (e->wslot >= 0 && e->wslot != me &&
        g_race_threads[me].clk.c[e->wslot] < e->wepoch) {
        race_report("read-after-unsync-write", a,
                    me, g_race_threads[me].clk.c[me], line,
                    e->wslot, e->wepoch, e->wline);
    }
    // Update last-reader (most recent wins; v1 trades precision for speed).
    e->rslot = me;
    e->repoch = g_race_threads[me].clk.c[me];
    e->rline = line;
    mutex_unlock(&g_race_mem_lock[si]);
}

void volt_race_write(void* ptr, i64 size, i64 line) {
    if (!__atomic_load_n(&g_race_enabled, __ATOMIC_RELAXED)) return;
    if (size <= 0) return;
    i32 me = race_current_slot();
    if (me < 0) return;
    i64 a = (i64)ptr;
    i64 h = race_hash_addr(a);
    i64 bi = h & (VOLT_RACE_MEM_BUCKETS - 1);
    i64 si = h & (VOLT_RACE_MEM_STRIPES - 1);
    mutex_lock(&g_race_mem_lock[si]);
    race_mem_entry_t* e = race_mem_get_or_create(a, bi, si);
    if (e->wslot >= 0 && e->wslot != me &&
        g_race_threads[me].clk.c[e->wslot] < e->wepoch) {
        race_report("write-after-unsync-write", a,
                    me, g_race_threads[me].clk.c[me], line,
                    e->wslot, e->wepoch, e->wline);
    }
    if (e->rslot >= 0 && e->rslot != me &&
        g_race_threads[me].clk.c[e->rslot] < e->repoch) {
        race_report("write-after-unsync-read", a,
                    me, g_race_threads[me].clk.c[me], line,
                    e->rslot, e->repoch, e->rline);
    }
    e->wslot = me;
    e->wepoch = g_race_threads[me].clk.c[me];
    e->wline = line;
    mutex_unlock(&g_race_mem_lock[si]);
}
