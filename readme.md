# volt
> A programming language inspired from C, Rust, Go and Zig.
>
> In fact the first name I gave was `crgz` but that was dorky, `volt` sounds better.

# why new language
- I love `Go`, easy and simple, gets you going and keeps you going.
- I'm curious about `Rust` and how it made it into the `Kernel` like a mental virus.
	- `Rust` is interesting as academic research model.
- I think better tooling around `C` can take care of all the issues that Rust wanted to fix.
	- in fact today in 2026 - AI is the answer to that gap and can take care of the issues Rust wants to fix.
	- in addition if there was going to be an agreement for better and cleaner `C` code writing style, that will help a lot with the "mess" in codebases; in that regard a timid and unfinished attempt was made here [libcore](https://github.com/codemodify/libcore).
- I'm curious about `Zig` and the intent of modernized `C`.

# how is it different
- it borrows the simple & easy style from `Go` but drops the GC
- it borrows the memory ownership concepts from `Rust` but with measure, no ugly junk code that resembles [PERL](https://www.google.com/search?q=PERL+ugly+code&udm=2) or [Carbide C++](https://www.google.com/search?q=Carbide+C%2B%2B+ugly+code&tbm=isch) where the code is just garbage on the screen and you need 6 PhDs to unpack it
- it plugs `C` if needed but does not allow it to crash
- it take `no-libc` approach from `Zig`, what you see is what you get, no hidden control flow

> In short: `Go` clothes, `Rust` spine, `C` sigils, `Zig` bare-metal posture.

> This looks like false positive unicorn, but it keeps producing.

# status
- early ALPHA as of 2026-05-22
- what can be tried out
	- language/keywords/syntax @ [testdata](./testdata)
	- concurrency
	- safety
	- memory semantics
	- compiling & running a bunch of hello worlds + producer/consumer
	- vscode extension for syntax
