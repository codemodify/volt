// testing.WriteBenchResultsJSON smoke test: construct a synthetic
// BenchResult slice and dump it to a file, then verify it can be
// read back as valid JSON (basic field presence). This exercises
// the JSON-aggregation path without paying the ~1-sec calibration
// cost of an actual RunBenchmark — that's covered by `volt test
// --bench-json` invoked from a separate harness.
package main
import "log"
import "testing"
import "os"
import "strings"

fun main() int {
	var results []BenchResult = new(3) []BenchResult {
		new BenchResult { Name: "BenchmarkA", Iters: 1000000, PsPerOp: 250, NsElapsed: 250000 },
		new BenchResult { Name: "BenchmarkB", Iters: 100,     PsPerOp: 9999999, NsElapsed: 999999 },
		new BenchResult { Name: "BenchmarkC", Iters: 1,       PsPerOp: 1, NsElapsed: 0 },
	}
	var path string = "/tmp/_volt_bench_json_smoke.json"
	var rc int = testing.WriteBenchResultsJSON(results, path)
	if rc != 0 {
		log.Println("WriteBenchResultsJSON failed rc=%d", rc)
		ret 1
	}
	var data string = ""
	var err error = nil
	data, err = os.ReadFile(path)
	if err != nil {
		log.Println("ReadFile failed")
		ret 2
	}
	if !strings.HasPrefix(data, "[{") { ret 3 }
	if !strings.Contains(data, "\"name\":\"BenchmarkA\"") { ret 4 }
	if !strings.Contains(data, "\"iters\":1000000") { ret 5 }
	if !strings.Contains(data, "\"ps_per_op\":250") { ret 6 }
	if !strings.Contains(data, "\"ns_elapsed\":250000") { ret 7 }
	if !strings.Contains(data, "\"name\":\"BenchmarkC\"") { ret 8 }
	if !strings.HasSuffix(strings.TrimRight(data, "\n"), "}]") { ret 9 }
	log.Println("bench JSON ok: %d bytes", len(data))
	ret 42
}
