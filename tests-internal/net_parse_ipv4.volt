package main
import "log"
import "net"

fun main() int {
	var pass int = 0

	// ParseIPv4 — well-known addresses.
	var ip int = 0
	var err error = nil

	ip, err = net.ParseIPv4("127.0.0.1")
	if err == nil { pass = pass + 1 }
	if ip == 2130706433 { pass = pass + 1 }   // 0x7F000001

	ip, err = net.ParseIPv4("0.0.0.0")
	if err == nil { pass = pass + 1 }
	if ip == 0 { pass = pass + 1 }

	ip, err = net.ParseIPv4("255.255.255.255")
	if err == nil { pass = pass + 1 }
	if ip == 4294967295 { pass = pass + 1 }

	ip, err = net.ParseIPv4("192.168.1.1")
	if err == nil { pass = pass + 1 }
	if ip == 3232235777 { pass = pass + 1 }   // 0xC0A80101

	// Error cases.
	ip, err = net.ParseIPv4("")
	if err != nil { pass = pass + 1 }
	if ip < 0 { ret 0 }                       // dead-use to satisfy checker

	ip, err = net.ParseIPv4("1.2.3")          // too few octets
	if err != nil { pass = pass + 1 }
	if ip < 0 { ret 0 }

	ip, err = net.ParseIPv4("256.0.0.1")      // out-of-range octet
	if err != nil { pass = pass + 1 }
	if ip < 0 { ret 0 }

	ip, err = net.ParseIPv4("a.b.c.d")        // non-numeric
	if err != nil { pass = pass + 1 }
	if ip < 0 { ret 0 }

	// IPv4String — format.
	if net.IPv4String(2130706433) == "127.0.0.1" { pass = pass + 1 }
	if net.IPv4String(0) == "0.0.0.0" { pass = pass + 1 }
	if net.IPv4String(4294967295) == "255.255.255.255" { pass = pass + 1 }
	if net.IPv4String(3232235777) == "192.168.1.1" { pass = pass + 1 }

	// Round-trip.
	var rt int = 0
	var rerr error = nil
	rt, rerr = net.ParseIPv4(net.IPv4String(2130706433))
	if rerr == nil { pass = pass + 1 }
	if rt == 2130706433 { pass = pass + 1 }

	rt, rerr = net.ParseIPv4(net.IPv4String(168430090))    // 10.10.10.10
	if rerr == nil { pass = pass + 1 }
	if rt == 168430090 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
