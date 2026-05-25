package main

import (
	"log"
	"os"
)

fun producer(out chan int, toProduceCount int) {
	def close(out)
	def log.Println("producer: done")

	for i:=0; i < toProduceCount; i++ {
		write(out, i)
	}
}

fun consumer(in chan int) int {
	def log.Println("consumer: done")

	var consumedCount int = 0
	for {
		if v, ok := read(in); !ok {
			ret consumedCount
		}
		consumedCount++
	}
}

fun main() {
	var ch chan int = new()

	var produceCount int = 10
	run producer(ch, produceCount)

	var consumedCount = consumer(ch)
	log.Println("finished: produced %d, consumed %d", produceCount, consumedCount)
}
