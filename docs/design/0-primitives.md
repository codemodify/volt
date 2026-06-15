# Primitives — read/write performance

A storage-and-perf companion to [0-primitives.volt](0-primitives.volt).
Covers what each primitive type lowers to, how it behaves under load/store,
and where the design choices are.

The opening framing — natural-width storage vs promoting everything to
i64 — applies to **all** primitives, so it comes first. Per-type notes
follow.

---

## The general principle: natural-width storage

**Don't promote small types to i64.** Storing `int8` as `int64` would
make things slower in aggregate and no faster for single-value access.
The current "natural width" mapping in
[codegen.go](../../internal/codegen/codegen.go) (int8 → i8, int16 → i16,
etc.) is the right design.

### Hardware basics

Both amd64 and arm64 natively support byte-granular memory access. A
byte load is the **same speed** as a 64-bit load when the data is in
L1 cache.

| Width  | amd64                | arm64               | Cycles (L1 hit) |
|--------|----------------------|---------------------|-----------------|
| 8-bit  | `mov al,  [rdi]`     | `ldrb w0, [x0]`     | ~1 |
| 16-bit | `mov ax,  [rdi]`     | `ldrh w0, [x0]`     | ~1 |
| 32-bit | `mov eax, [rdi]`     | `ldr  w0, [x0]`     | ~1 |
| 64-bit | `mov rax, [rdi]`     | `ldr  x0, [x0]`     | ~1 |

There is no hardware reward for padding everything to 64 bits.

### The granularity that actually matters: the cache line

Above the register layer, the smallest unit moved between RAM and the
CPU is a **cache line — 64 bytes** on both amd64 and arm64 (some Apple
Silicon variants use 128). When you load 1 byte from RAM, you pay to
drag 64 bytes into L1.

- `[]int8` of 1000 elements = **1000 bytes** = ~16 cache lines.
- `[]int64` "aliasing" those same 1000 values = **8000 bytes** = ~125 cache lines.

That's **8× more memory bandwidth, 8× more cache pollution, 8× more
L1 evictions** for a sequential scan. That's where the perf hit lives
— not in the load instruction itself.

### What happens inside a register

Once a value is loaded into a register, every CPU register is 64 bits
wide. An `int8` sits in a 64-bit register zero- or sign-extended.

- Load `int8` from memory → 1 cycle (byte load + implicit zero/sign extend, free).
- Arithmetic on it → operates on the full 64-bit register; same speed as int64.
- Store back → 1 cycle (byte store).

**Inside the register, there is no speed difference between int8 and
int64.** The "should I use int8 or int64 for this local?" question only
matters when the value lives in memory (struct field, slice element).

### Aliasing int8 as int64 to "read the byte part"?

You can, but it hurts you twice over.

**To read it:** `load i64, then trunc to i8` — one extra instruction
compared to `load i8` directly. About the same speed in practice, but
no faster.

**To write it:** this is the real killer. You can't write just the low
8 bits of an i64 without a read-modify-write:

```
load i64        ; ~1 cycle
and  ~0xff      ; ~1 cycle, mask out the byte
or   new_byte   ; ~1 cycle, set the new byte
store i64       ; ~1 cycle
```

That's **4× the work** compared to `store i8` (1 cycle). And it forces a
redundant *read* even when you only wanted to *write*.

**Memory footprint:** 8× the bytes, 8× the cache lines per array element.

### Cases where promoting widths *does* help

1. **i32 vs i64 for hot scalars on amd64.** 32-bit instructions have
   shorter encodings (better i-cache density) and 32-bit division is
   often faster. *Real perf win for individual ints, but not for arrays.*
   The rule is "use the narrowest type that holds your value" — not
   "always use 64."

2. **Padding to align.** A struct field whose natural alignment is 8
   gets up to 7 bytes of padding before it regardless of its
   predecessor's size. So storing a `bool` as i8 vs i64 right before
   an `int64` field — same total size either way after alignment. In
   this specific case, promoting "for free" is OK.

3. **Bools in LLVM.** i1 (single bit) gets stored as i8 anyway by the
   LLVM backend — you can't have addressable bits. (See bool below.)

### The mental model

| State                              | Width that matters                                              |
|------------------------------------|-----------------------------------------------------------------|
| In a register (during compute)     | 64 bits — everything is 64-bit                                  |
| In memory (stack/heap/struct/array)| Whatever the type says — smaller is denser, denser is faster for arrays |

The transitions between the two (load/store) are byte-granular and
equally fast for all widths. The cumulative effect of array/struct
density is what shows up in benchmarks.

---

## Per-type notes

### Integer types (`int8…int64`, `uint8…uint64`, `byte`, `int`, `uint`)

| Type alias | LLVM | Bytes |
|---|---|---|
| `int8`,  `uint8`,  `byte` | `i8`  | 1 |
| `int16`, `uint16`         | `i16` | 2 |
| `int32`, `uint32`         | `i32` | 4 |
| `int64`, `uint64`, `int`, `uint` | `i64` | 8 |

**Status:** correct. Natural widths, packed in arrays/structs,
register-resident for locals.

**Signed vs unsigned have identical storage.** The s/u distinction
lives in the *operations* — `sdiv` vs `udiv`, `ashr` vs `lshr`, `sext`
vs `zext` at load. From a load/store perspective, `int8` and `uint8`
are interchangeable.

**Aliases worth knowing:**
- `int`  == `int64`  (one machine word — the default integer)
- `uint` == `uint64`
- `byte` == `uint8`

**Use `int` for API boundaries** unless the narrowness is part of the
contract — avoids needless truncation/sign-extension at every call.

### `bool` — i1, stored as i8

LLVM type: `i1` (single bit at the type level).

What actually happens in memory:
- **In a register**: 1 bit (but the register itself is 64).
- **In a stack slot / struct field**: LLVM stores `i1` as `i8` because
  you can't address sub-byte memory. So a `bool` local takes 1 byte.
- **In a struct**: each `bool` field eats a full byte; the compiler
  does not bit-pack adjacent bools into one byte.

Bit-packing would save space for huge arrays (8 bools per byte) but
turn every read/write into a load + mask + shift + store — too costly
for the marginal density win.

**Status:** correct. If dense-boolean perf ever matters, ship a
`bitset` library type rather than complicating the primitive.

### `float`, `float32` — IEEE 754

| Type alias | LLVM | Bytes |
|---|---|---|
| `float32` | `float`  | 4 |
| `float`, `float64` | `double` | 8 |

- amd64: uses `xmm` registers (128-bit SIMD); for scalar ops the
  bottom 32 / 64 bits are what's used. Same speed in registers; 32-bit
  takes half the memory bandwidth.
- arm64: scalar fp in `s` (32-bit) / `d` (64-bit) registers.

Same advice as ints — narrowest type that holds your value range.

### `string` — fat pointer + heap backing

Storage: `%string = { ptr, i64 }` — 16-byte fat pointer carrying the
backing-bytes pointer and the length. Content lives in a separate
allocation (`.rodata` string literal or heap buffer).

Read perf:
- Get a byte: `extractvalue` (free) + `load i8` from `ptr + i`.
- Get the length: `extractvalue` (free).
- Pass to a function: pass the whole 16-byte struct as two registers,
  or by pointer (ABI choice).

Storage layout cost:
- `[]string` of N elements: 16 bytes per slot. **4 strings per cache
  line.** Each string access touches at least two cache lines (header
  + content).

Length-prefixed vs null-terminated: length-prefixed wins for `len()`
(O(1) vs O(n)) and for substrings (no need to copy to null-terminate).
16-byte header vs 8 is worth it.

### `[]T` — fat pointer header

Storage: `%slice = { ptr, i64 }` — same shape as string but with the
element pointer typed by `T`.

### `map[K]V` — handle to runtime hash table

Storage: `ptr` (8 bytes). Behind it: a runtime struct with a lock,
entry count, and a fixed array of 256 buckets, each holding a singly-
linked list of entries. djb2 hash on the key.

Perf:
- Insert / lookup: hash → bucket → linear scan of chain. Amortized
  O(1) when chains are short.

### `chan T` — handle to runtime channel

Storage: `ptr` (8 bytes). Behind it: a runtime struct with futex lock,
condition variables (not-full / not-empty), and a ring buffer sized
to the channel's capacity.

**Reference-typed by design.** Copying a `chan T` value gives another
handle to the same channel — both endpoints must be able to hold a
copy. Not move-tracked.

Perf: futex-based blocking. Uncontested send/recv is a CAS dance
(~10ns); contested → syscall (~1µs).

### `error`, `any` — opaque pointer (reference-typed, nilable)

Storage: `ptr` (8 bytes). Opaque interface-shaped value.

When interface dispatch lands, the layout will likely become
`{ ptr_to_value, ptr_to_vtable }` — a fat pointer carrying the value
plus its method table (the same shape as Go's `iface`).

### User structs — LLVM struct, source-order fields

Storage: `%TypeName` — fields laid out at natural alignment, padded
to satisfy the largest field's alignment.

The optimizer:
- Promotes small structs into registers when it can.
- Lays out fields in source order — **does not** reorder for minimal
  padding (same as Go and C; some languages do reorder).

Example of how field order affects size:

```
struct { a int8; b int64; c int8 }   // 24 bytes: 1 + 7 pad + 8 + 1 + 7 pad
struct { b int64; a int8; c int8 }   // 16 bytes: 8 + 1 + 1 + 6 pad
```

Source-order layout matches user mental model. Reordering would
require a way to opt into a packed-vs-C layout per type, which volt
does not have.

### `struct{}` — zero size

LLVM treats anonymous-empty struct as zero-size. Useful for set
semantics (`map[string]struct{}`) — no bytes consumed per element.

### Peeks & loans: `&T` (peek), `*T` (loan & owned pointer)

Storage: `ptr` (8 bytes), regardless of `T`'s size. A peek (`&T`,
read-only) and a loan (`*T`, write-in-place) are purely compile-time
access markers over someone else's value. An owned pointer (`*T`) is a
real handle to a heap object you made with `new` — read with `*p`, write
through it directly. See [2-ownership.volt](2-ownership.volt) for the rules.

---

## Practical guidance for volt users

- For a **single local** (`var n int8 = …`), the type choice is a
  documentation / range-checking concern, not a perf concern.
- For a **struct field** or **slice element**, choose the narrowest
  type that fits the value range. The cache-line math is real.
- For an **API boundary** (function param/return), prefer `int` (alias
  for `int64`) unless narrowness is part of the contract — it avoids
  needless truncation/sign-extension at every call.


Schedule once primitive/allocation/ownership topics are closed.
