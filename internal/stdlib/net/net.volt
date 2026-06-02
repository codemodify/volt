// Package net: minimal TCP/IPv4 client + server.
//
// Surface (v1):
//   Listen(addr string)         (Listener, error)
//   Dial(addr string)           (Conn, error)
//   (l Listener).Accept()       (Conn, error)
//   (l Listener).Close()        error
//   (c Conn).Read()             (string, error)   — reads until peer closes
//   (c Conn).Write(s)           (int, error)
//   (c Conn).Close()            error
//
// addr is "host:port" — host is dotted-decimal IPv4 ("127.0.0.1") or
// empty for INADDR_ANY (Listen only). Domain names not yet resolved
// (no DNS). UDP, IPv6, deadlines, SO_KEEPALIVE — future work.

package net

import "syscall"
import "errors"
import "strings"
import "strconv"

type Listener struct {
    fd     int
    closed bool
}

type Conn struct {
    fd     int
    closed bool
}

// parseAddr splits "host:port" → (ip32, port, error). Empty host
// returns ip=0 (INADDR_ANY).
fun parseAddr(addr string) (int, int, error) {
    var colon int = strings.Index(addr, ":")
    if colon < 0 {
        ret 0, 0, errors.New("net: address missing ':'")
    }
    var host string = ""
    for k:=0; k < colon; k++ { host = host + chr(addr[k]) }
    var portStr string = ""
    for k:=colon+1; k < len(addr); k++ { portStr = portStr + chr(addr[k]) }
    var port int = 0
    var perr error = nil
    port, perr = strconv.Atoi(portStr)
    if perr != nil {
        ret 0, 0, errors.New("net: invalid port")
    }
    var ip int = 0
    if len(host) > 0 {
        var ip2 int = 0
        var ierr error = nil
        ip2, ierr = parseIPv4(host)
        if ierr != nil { ret 0, 0, ierr }
        ip = ip2
    }
    ret ip, port, nil
}

// parseIPv4 turns "a.b.c.d" into the host-order int 0xAABBCCDD.
fun parseIPv4(s string) (int, error) {
    var parts []string = strings.Split(s, ".")
    if len(parts) != 4 { ret 0, errors.New("net: bad IPv4 address") }
    var result int = 0
    for i:=0; i < 4; i++ {
        var oct int = 0
        var err error = nil
        oct, err = strconv.Atoi(parts[i])
        if err != nil { ret 0, errors.New("net: bad IPv4 octet") }
        if oct < 0 { ret 0, errors.New("net: bad IPv4 octet") }
        if oct > 255 { ret 0, errors.New("net: bad IPv4 octet") }
        result = result * 256 + oct
    }
    ret result, nil
}

// ParseIPv4 parses dotted-decimal "a.b.c.d" into a host-order int
// (0xAABBCCDD). Public surface over the internal parseIPv4 helper.
// Each octet must be 0..255; out-of-range or non-numeric segments
// return an error. Useful for converting user-typed addresses to
// the integer form `syscall.TcpListen` / `TcpDial` expect.
fun ParseIPv4(s string) (int, error) {
    var ip int = 0
    var err error = nil
    ip, err = parseIPv4(s)
    ret ip, err
}

// IPv4String formats a host-order IPv4 int (0xAABBCCDD) back into
// dotted-decimal "a.b.c.d". Inverse of ParseIPv4; round-trips for
// any valid input. Useful for logging / display after parsing.
fun IPv4String(ip int) string {
    var a int = (ip / 16777216) & 255
    var b int = (ip / 65536) & 255
    var c int = (ip / 256) & 255
    var d int = ip & 255
    var out string = ""
    out = out + strconv.Itoa(a) + "." + strconv.Itoa(b) + "." + strconv.Itoa(c) + "." + strconv.Itoa(d)
    ret out
}

fun Listen(addr string) (Listener, error) {
    var ip int = 0
    var port int = 0
    var perr error = nil
    ip, port, perr = parseAddr(addr)
    if perr != nil {
        ret new Listener {fd: -1, closed: true}, perr
    }
    var fd int = syscall.TcpListen(ip, port, 16)
    if fd < 0 {
        ret new Listener {fd: -1, closed: true}, errors.New("net: listen failed")
    }
    ret new Listener {fd: fd, closed: false}, nil
}

fun Dial(addr string) (Conn, error) {
    var ip int = 0
    var port int = 0
    var perr error = nil
    ip, port, perr = parseAddr(addr)
    if perr != nil {
        ret new Conn {fd: -1, closed: true}, perr
    }
    if ip == 0 { ip = 0x7F000001 }   // "" host → 127.0.0.1
    var fd int = syscall.TcpDial(ip, port)
    if fd < 0 {
        ret new Conn {fd: -1, closed: true}, errors.New("net: dial failed")
    }
    ret new Conn {fd: fd, closed: false}, nil
}

fun (l Listener) Accept() (Conn, error) {
    if l.closed {
        ret new Conn {fd: -1, closed: true}, errors.New("net: listener closed")
    }
    var fd int = syscall.TcpAccept(l.fd)
    if fd < 0 {
        ret new Conn {fd: -1, closed: true}, errors.New("net: accept failed")
    }
    ret new Conn {fd: fd, closed: false}, nil
}

fun (l Listener) Close() error {
    if l.closed { ret nil }
    var rc int = syscall.Close(l.fd)
    l.closed = true
    if rc < 0 { ret errors.New("net: close failed") }
    ret nil
}

fun (c Conn) Read() (string, error) {
    if c.closed { ret "", errors.New("net: conn closed") }
    var s string = syscall.ReadAll(c.fd)
    ret s, nil
}

fun (c Conn) Write(s string) (int, error) {
    if c.closed { ret 0, errors.New("net: conn closed") }
    var n int = syscall.WriteAll(c.fd, s)
    if n < 0 {
        ret 0, errors.New("net: write failed")
    }
    ret n, nil
}

fun (c Conn) Close() error {
    if c.closed { ret nil }
    var rc int = syscall.Close(c.fd)
    c.closed = true
    if rc < 0 { ret errors.New("net: close failed") }
    ret nil
}
