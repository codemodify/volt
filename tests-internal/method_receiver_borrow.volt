// Method-receiver borrow checking (item 9): calling a method borrows
// the receiver for the call's duration. Positive cases — no borrow
// held, so both mutating (*T) and shared (&T) receivers are fine; and
// a held SHARED borrow still permits shared-receiver method calls.
package main
import "log"

type Counter struct {
	value int
}

fun (c *Counter) Inc()      { c.value = c.value + 1 }
fun (c &Counter) Get() int  { ret c.value }

fun main() int {
	var ct Counter = new Counter {value: 0}

	// No borrow held → mutating + shared method calls both fine.
	ct.Inc()
	ct.Inc()
	ct.Inc()
	if ct.Get() != 3 { ret 1 }

	// A held SHARED borrow still permits a shared-receiver method.
	{
		var s &Counter = &ct
		var via int = ct.Get()    // shared receiver, shared borrow → OK
		if via != 3 { ret 2 }
		var through int = s.Get()  // method via the borrow itself
		if through != 3 { ret 3 }
	}

	// After the borrow ends, mutating methods work again.
	ct.Inc()
	if ct.Get() != 4 { ret 4 }

	log.Println("method receiver borrow ok: %d", ct.Get())
	ret 42
}
