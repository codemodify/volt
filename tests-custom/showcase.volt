package main

import (
	"log"
	"os"
	"time"
)

type Stats struct {
	grandSum  int
	completed int
}

fun producer(out chan write int, count int) {
	def close(out)
	for i:=1; i <= count; i++ {
		write(out, i * i)
	}
}

fun worker(id int, jobs chan read int, results chan write int) {
	var total int = 0
	for {
		v, ok := read(jobs)
		if !ok { break }
		total = total + v
		time.Sleep(time.Microsecond)
	}
	write(results, total)
}

fun collector(in chan read int, stats mutex Stats, expected int, wg waitgroup) {
	def wg.Done()
	for i:=0; i < expected; i++ {
		if v, ok := read(in); ok {
			var s Stats = stats.Lock()
			s.grandSum = s.grandSum + v
			s.completed = s.completed + 1
		}
	}
}

fun banner(o once, label string) {
	o.Do(fun() {
		log.Println("=== %s ===", label)
	})
}

fun main() {
	var welcome once = new()
	banner(welcome, "volt pipeline")

	var inputs []int = new {1, 4, 9, 16, 25, 36, 49, 64, 81}
	var expected int = 0
	for _, v := range inputs {
		expected = expected + v
	}

	var jobs    chanN1 int = new(8)
	var results chan1N int = new(4)
	var stats   mutex Stats = new {grandSum: 0, completed: 0}
	var active  atomic int = new {}
	var wg      waitgroup  = new()

	var workers int = 3

	run producer(jobs, len(inputs))
	for i:=0; i < workers; i++ {
		active.Add(1)
		run worker(i, jobs, results)
	}

	wg.Add(1)
	run collector(results, stats, workers, wg)
	wg.Wait()

	var final Stats = stats.Lock()
	log.Println("workers=%d grandSum=%d completed=%d active=%d",
		workers, final.grandSum, final.completed, active.Read())

	if final.grandSum == expected {
		os.Exit(0)
	}
	os.Exit(1)
}
