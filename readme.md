# binavolt

> A programming language inspired by C, Rust, Go, and Zig.
>
> First codename was `crgz` — dorky. `volt` is cleaner.

## why new language

- I love `Go` — easy, simple, gets you going and keeps you going.
- I'm curious about `Rust` and how it made it into the kernel.
  - `Rust` is interesting as an academic research model.
- I think better tooling around `C` can address most of the issues Rust set out to fix.
  - AI in 2026 is the answer to that gap and can take care of the issues Rust wants to solve.
  - An agreement on cleaner `C` style would help a lot — a timid attempt at [libcore](https://github.com/codemodify/libcore).
- I'm curious about `Zig` and modernized-`C` intent.

## how is it different

- Borrows the simple & easy style from `Go` but drops the GC.
- Borrows the memory-ownership concepts from `Rust` — with measure. No ugly code that resembles [PERL](https://www.google.com/search?q=PERL+ugly+code&udm=2) or [Carbide C++](https://www.google.com/search?q=Carbide+C%2B%2B+ugly+code&tbm=isch) where you need 6 PhDs to unpack it.
- Plugs `C` if needed, but doesn't let it crash.
- Takes the `no-libc` approach from `Zig` — what you see is what you get, no hidden control flow.

> In short: `Go` clothes, `Rust` spine, `C` sigils, `Zig` bare-metal posture.

## quick start

```bash
# Build the compiler.
go build -o volt ./cmd/volt

# Compile + run a sample.
./volt run docs/samples/parallel_sum.volt
./volt run docs/samples/json_format.volt

# Try a small program.
cat > hello.volt <<EOF
package main
import "log"
fun main() int {
    log.Println("hello from volt")
    ret 42
}
EOF
./volt run hello.volt
```

## status (2026-06-02)

- super early alpha, still in design + trial loop
- sample tests compile and run
- concurrency works
- see [status](./status.md)
- binary sizes grew a bit as more concurrency was getting polished but acceptable for what it offers
	- [producer-consumer](./tests-custom/producer-consumer.volt) binary is 154k
	- [showcase](./tests-custom/showcase.volt) binary is 260k

## status (2026-05-26)

- Build target: `linux/amd64`, `linux/arm64`. No libc.
- 28 stdlib packages, 139 internal tests, 0 known crashes.
- Three-script regression suite — `scripts/{smoke,run_smoke,fmt_smoke}.sh`.

### What works today

| Area            | Notes                                                                                                                                                                                                                                                                                                          |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Language        | `fun`, `var`, `ret`, `if`, `for`, `for i := range N`, channels, atomics, mutex/rwmutex, waitgroup, once                                                                                                                                                                                            |
| Memory          | Ownership/move tracking, simple sentinel errors, Drop auto-close on files                                                                                                                                                                                                                                      |
| Concurrency     | `run f(...)` (OS thread), `chan` with `chan11`/`1N`/`N1`/`NN` multiplicity contracts + read/write direction                                                                                                                                                                                        |
| Stdlib          | `bufio`, `bytes`, `crypto/{hmac,md5,rand,sha1,sha256}`, `encoding/{base64,hex}`, `errors`, `fmt`, `hash/fnv`, `io`, `json`, `log`, `maps`, `math`, `net`, `os`, `path/filepath`, `slices`, `sort`, `strconv`, `strings`, `syscall`, `testing`, `time`, `unicode` |
| Tooling         | `volt {build,run,test,fmt,doc,dump-ir,dump-tokens,env,version}`, `volt mod {init,get,tidy,verify}`, `volt lsp`                                                                                                                                                                                           |
| LSP             | Hover, go-to-definition, references, rename, completion, semantic tokens, code actions, document symbols, signature help, folding, document links, document highlights — for both local code and the embedded stdlib                                                                                          |
| Module system   | volt.mod (single + block require), volt.sum (h1: hashes), versioned `replace` directives, transitive walk with `mod get`, MVS-style version selection                                                                                                                                                      |
| Build artifacts | LLVM IR via clang, mold linker, DWARF debug info (`-g`)                                                                                                                                                                                                                                                      |

### How to learn

- **Samples**: [`docs/samples/`](docs/samples) — small annotated programs.
- **Spec / design**: [`docs/design/0-intent.volt`](docs/design/0-intent.volt) is the canonical syntax/semantics reference.
- **API docs**: `volt doc <stdlib-pkg>` for any of the 28 packages — `volt doc strings`, `volt doc crypto/sha256`, `volt doc bytes`, etc.
- **Test corpus**: [`tests-internal/`](tests-internal) — every language and stdlib feature has at least one end-to-end test.

### What's NOT yet here

- Race detector (D.1)
- Lock-free MPMC channels (D.2)
- macOS port (D.3)
- Self-hosting compiler (D.5)
- Float-only stdlib (Sqrt/Pi/Sin) — int math only for now

These are tracked in [TODO.md](TODO.md).
