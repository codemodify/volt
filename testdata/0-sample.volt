package main

import (
	"http"
	"log"
	"time"
)

fun downloader(url string, out chan byte) {
	def close(out)
	def log.Println("downloader: done")

	var resp http.Response
	var err error
	resp, err = http.Get(url)
	if err != nil {
		log.Println("downloader: error opening", url, ":", err)
		ret
	}
	def resp.Close()

	var buf []byte = new(4096)
	for {
		var n int
		n, err = resp.Body.Read(buf)

		// Stream whatever bytes we got.
		var i int = 0
		for i < n {
			out <- buf[i]   // bare `buf[i]` → owned byte moves into channel
			i = i + 1
		}

		if err != nil {
			// io.EOF or a real error — either way, we're done streaming.
			ret
		}
	}
}

fun consumer(in chan byte, done chan int) {
	def log.Println("consumer: done")

	var total int = 0
	for {
		var b byte
		var ok bool
		b, ok = <-in
		if !ok {
			done <- total
			ret
		}

		total = total + 1
		if total % 1024 == 0 {
			log.Println("consumer: processed", total, "bytes (latest byte:", b, ")")
		}

		time.Sleep(10 * time.Microsecond)
	}
}

fun main() {
	var url string = "http://example.com/data.bin"

	var bytes chan byte = new(256)
	var done chan int = new(1)

	run downloader(url, bytes)
	run consumer(bytes, done)

	var total int = <-done

	log.Println("main: finished. total bytes processed:", total)
}
