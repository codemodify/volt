// volt:noformat — spec file; hand-aligned.
// =====================================================================
// terminal.volt — the `term` package: raw-mode terminal control
// =====================================================================
// volt has two ways to read input. `os.ReadLine` is line-oriented: it
// echoes, runs the terminal in canonical mode, and returns only when the
// user presses Enter — right for prompts, useless for a full-screen UI.
// The `term` package is the other way: single keystrokes with no echo,
// the window size, and an input wait with a timeout. Together they make
// interactive TUIs possible (see tests-custom/tui for a full toolkit).
//
// `term` is a thin layer over five COMPILER INTRINSICS, lowered in
// codegen to runtime calls that issue raw Linux syscalls (ioctl / read /
// ppoll) — no libc. Linux-only in v1, like the rest of volt's OS surface.
//
//   Intrinsic (package syscall)     Runtime symbol        Syscall
//   ---------------------------     ------------------    ---------------
//   syscall.TermSize(fd)            volt_term_size        ioctl TIOCGWINSZ
//   syscall.TermMakeRaw(fd)         volt_term_makeraw     ioctl TCGETS/TCSETS
//   syscall.TermRestore(fd)         volt_term_restore     ioctl TCSETS
//   syscall.ReadByte(fd)            volt_read_byte        read
//   syscall.PollIn(fd, ms)          volt_poll_in          ppoll

// ---- public surface (package term) ----------------------------------
//
//   Size()        (int, int)   terminal (rows, cols); 24x80 on a non-tty
//   MakeRaw()     int          enter cbreak mode; 0 ok, <0 -errno
//   Restore()     int          undo MakeRaw (no-op if never entered)
//   PollIn(ms)    bool         is a byte readable within `ms`? ms<0 blocks
//   ReadByte()    int          one byte (0..255), KeyEOF(-1), KeyErr(-2)
//   ReadKey()     int          one decoded key: a byte, or a Key* code

// Raw ("cbreak") mode disables ICANON + ECHO (no line buffering, no echo)
// and ISIG (so Ctrl-C arrives as the byte 3 rather than killing the
// process — a TUI can then run its restore-on-exit path no matter how the
// user quits). MakeRaw saves the prior settings; Restore puts them back.

// ReadKey decodes the common escape sequences into sentinels (codes
// >= 0x1000 so they never collide with a byte). Ordinary keys come back
// as their byte value; LF is normalized to KeyEnter:
//
//   KeyUp KeyDown KeyLeft KeyRight        ESC [ A/B/C/D
//   KeyHome KeyEnd KeyPgUp KeyPgDn        ESC [ H/F , ESC [ 5~/6~
//   KeyDel KeyInsert                      ESC [ 3~ / 2~
//   KeyEnter KeyEsc KeyTab KeyBackspace KeyCtrlC KeySpace   (single bytes)

// ---- the canonical interactive loop ---------------------------------
// MakeRaw, defer Restore, then loop: draw, then wait up to `tickMs` for a
// key. A key drives input; a timeout drives animation. The PollIn timeout
// is what lets the screen refresh on a tick while staying instantly
// responsive to input.

import "term"
import "fmt"

fun runLoop() {
    var rows int = 0
    var cols int = 0
    rows, cols = term.Size()

    if term.MakeRaw() != 0 {
        ret                         // not a tty — caller draws statically
    }
    def term.Restore()              // guarantees the terminal is restored
    fmt.Print(altScreen() + hideCursor())
    def showAndLeave()              // (helper: show cursor, leave alt screen)

    var running bool = true
    for running {
        render(rows, cols)          // paint a frame
        if term.PollIn(90) {        // up to 90ms for a key
            var k int = term.ReadKey()
            if k == term.KeyCtrlC || k == 113 {   // Ctrl-C or 'q'
                running = false
            } else {
                handleKey(k)
            }
        } else {
            tick()                  // advance spinners / clocks
        }
    }
}

// ---- non-tty fallback ------------------------------------------------
// MakeRaw returns a negative errno when stdin is not a terminal (piped,
// redirected, CI). The right move is to render a single static frame and
// exit rather than block — so the same program is safe to run headless.

// ---- escape sequences you'll emit yourself --------------------------
// term controls INPUT; OUTPUT is just strings you print. The useful ones
// (chr(27) is ESC):
//
//   ESC[H              cursor home              ESC[2J     clear screen
//   ESC[<r>;<c>H       move to row;col (1-based)
//   ESC[?25l / ?25h    hide / show cursor
//   ESC[?1049h / 1049l enter / leave alt screen (preserves scrollback)
//   ESC[0m             reset style
//   ESC[38;5;<n>m      256-color foreground   ESC[48;5;<n>m  background
//   ESC[1m / 4m / 7m   bold / underline / reverse
//
// A full compositor (cell grid, widgets, event loop) built on all of the
// above lives in tests-custom/tui.
