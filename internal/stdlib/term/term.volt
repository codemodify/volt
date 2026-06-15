// Package term: low-level terminal control — the foundation for
// interactive, full-screen TUIs in volt.
//
// Volt's other input path (os.ReadLine) is line-oriented: it echoes,
// waits for Enter, and runs the terminal in canonical mode. A TUI needs
// the opposite — single keystrokes, no echo, no line buffering, plus a
// way to learn the window size and to wait for input with a timeout so
// the screen can refresh on a tick. This package provides exactly that,
// as a thin layer over five compiler intrinsics (lowered to ioctl/read/
// ppoll in the runtime):
//
//   Size()        (rows, cols int)   — terminal dimensions (TIOCGWINSZ)
//   MakeRaw()     int                — enter cbreak mode (0 / -errno)
//   Restore()     int                — undo MakeRaw (0 / -errno)
//   PollIn(ms)    bool               — is a key available within `ms`?
//   ReadByte()    int                — one raw byte (0..255, -1 EOF, -2 err)
//   ReadKey()     int                — one decoded key (byte or Key* code)
//
// Lifecycle: MakeRaw on fd 0, `def term.Restore()` to guarantee the
// terminal is put back, then loop on ReadKey/PollIn. MakeRaw disables
// ISIG, so Ctrl-C is delivered as the byte 3 (KeyCtrlC) rather than
// killing the process — handle it as "quit" so Restore always runs.
//
// Linux-only (v1), like the rest of volt's OS surface.

package term

import "syscall"

// Special-key sentinels returned by ReadKey for multi-byte escape
// sequences. They sit above the 0..255 byte range so they never collide
// with an ordinary key. Ordinary keys are returned as their byte value
// (e.g. 'a' = 97); the named control bytes below are provided for
// readability.
const (
    // Multi-byte sequences (arrows, navigation), reported as synthetic codes.
    KeyUp     = 0x1001
    KeyDown   = 0x1002
    KeyRight  = 0x1003
    KeyLeft   = 0x1004
    KeyHome   = 0x1005
    KeyEnd    = 0x1006
    KeyPgUp   = 0x1007
    KeyPgDn   = 0x1008
    KeyDel    = 0x1009
    KeyInsert = 0x100A

    // Common single bytes, named for clarity. ReadKey normalizes LF(10)
    // to KeyEnter(13) so both Enter conventions read the same.
    KeyCtrlC     = 3
    KeyTab       = 9
    KeyEnter     = 13
    KeyEsc       = 27
    KeySpace     = 32
    KeyBackspace = 127

    // Non-key results from ReadByte/ReadKey.
    KeyEOF = -1
    KeyErr = -2
)

// Size returns the terminal's (rows, cols). Falls back to a sane 24x80
// when the size can't be determined (e.g. stdout is not a terminal),
// so callers never have to special-case a zero dimension.
fun Size() (int, int) {
    var packed int = syscall.TermSize(1)
    if packed <= 0 {
        ret 24, 80
    }
    var rows int = (packed >> 16) & 0xFFFF
    var cols int = packed & 0xFFFF
    if rows == 0 || cols == 0 {
        ret 24, 80
    }
    ret rows, cols
}

// MakeRaw puts standard input into cbreak mode: no echo, no line
// buffering, no signal generation (Ctrl-C becomes a readable byte), one
// byte delivered at a time. Returns 0 on success or a negative errno
// (e.g. when stdin is not a terminal). Pair with `def term.Restore()`.
fun MakeRaw() int {
    ret syscall.TermMakeRaw(0)
}

// Restore returns standard input to the settings captured by the most
// recent MakeRaw. Safe to call even if MakeRaw never ran (no-op).
fun Restore() int {
    ret syscall.TermRestore(0)
}

// PollIn reports whether a byte is available on standard input within
// `ms` milliseconds. ms == 0 polls instantly (non-blocking); ms < 0
// blocks until input arrives. Drives both escape-sequence disambiguation
// and tick-based screen refresh.
fun PollIn(ms int) bool {
    ret syscall.PollIn(0, ms) == 1
}

// ReadByte reads a single raw byte from standard input: 0..255 on
// success, KeyEOF(-1) at end of input, KeyErr(-2) on error. Blocks until
// a byte is available (in raw mode).
fun ReadByte() int {
    ret syscall.ReadByte(0)
}

// ReadKey reads one logical keypress and decodes the common terminal
// escape sequences (arrows, Home/End/PgUp/PgDn/Delete/Insert) into the
// Key* sentinels. Ordinary keys come back as their byte value; LF is
// normalized to KeyEnter. A lone Escape (no sequence following within a
// short window) returns KeyEsc. Returns KeyEOF/KeyErr on end/err.
fun ReadKey() int {
    var c int = syscall.ReadByte(0)
    if c < 0 {
        ret c                       // KeyEOF / KeyErr
    }
    if c == 10 {
        ret KeyEnter                // normalize LF -> Enter
    }
    if c != 27 {
        ret c                       // ordinary byte (printables, Tab, CR, DEL, Ctrl-C, ...)
    }

    // c == ESC: either a bare Escape or the start of a CSI/SS3 sequence.
    // If nothing follows promptly, it was a real Escape keypress.
    if !PollIn(30) {
        ret KeyEsc
    }
    var b1 int = syscall.ReadByte(0)
    if b1 != 91 && b1 != 79 {       // not '[' (CSI) and not 'O' (SS3)
        ret KeyEsc
    }
    var b2 int = syscall.ReadByte(0)
    if b2 < 0 {
        ret KeyEsc
    }

    // Letter-terminated forms: ESC [ A / B / C / D / H / F  (and SS3 O x).
    if b2 == 65 { ret KeyUp }       // 'A'
    if b2 == 66 { ret KeyDown }     // 'B'
    if b2 == 67 { ret KeyRight }    // 'C'
    if b2 == 68 { ret KeyLeft }     // 'D'
    if b2 == 72 { ret KeyHome }     // 'H'
    if b2 == 70 { ret KeyEnd }      // 'F'

    // Numeric forms: ESC [ <n> ~   (consume the digits and trailing '~').
    if b2 >= 48 && b2 <= 57 {
        var n int = b2 - 48
        var t int = syscall.ReadByte(0)
        for t >= 48 && t <= 57 {
            n = n * 10 + (t - 48)
            t = syscall.ReadByte(0)
        }
        // t is now '~' (126) for well-formed sequences.
        if n == 1 { ret KeyHome }
        if n == 2 { ret KeyInsert }
        if n == 3 { ret KeyDel }
        if n == 4 { ret KeyEnd }
        if n == 5 { ret KeyPgUp }
        if n == 6 { ret KeyPgDn }
        if n == 7 { ret KeyHome }
        if n == 8 { ret KeyEnd }
        ret KeyEsc
    }

    ret KeyEsc
}
