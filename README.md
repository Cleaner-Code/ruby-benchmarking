# Ruby Benchmark Suite

Benchmarking environment comparing MRI Ruby and JRuby performance, with focus on finding optimal coding techniques.

## Versions

- **MRI Ruby**: 3.4.7
- **JRuby 10**: 10.0.2.0 (Ruby 3.4.2 compatible) + Java Temurin 21.0.9 LTS
- **JRuby 1.7**: 1.7.27 (Ruby 1.9.3 compatible) + Java Corretto 8

## Project Structure

```
bench/
├── run_techniques_all.sh     # Main entry: run MRI, JRuby 10, JRuby 1.7, compare
├── run_techniques.rb         # Benchmark runner
├── compare_techniques.rb     # MRI vs JRuby comparison
├── run_gc_comparison.sh      # GC comparison: run with G1, Parallel, ZGC, Shenandoah
├── run_gc_benchmarks.rb      # GC-sensitive benchmark runner
├── compare_gc.rb             # GC comparison report generator
├── lib/
│   ├── benchmark_runner.rb   # Core benchmarking library
│   └── ruby19_compat.rb      # Ruby 1.9.3 compatibility polyfills
├── benchmarks/
│   ├── technique_benchmarks.rb  # Compare different approaches (24 categories)
│   ├── string_benchmarks.rb     # String operations
│   ├── array_benchmarks.rb      # Array operations
│   ├── hash_benchmarks.rb       # Hash operations
│   ├── parsing_benchmarks.rb    # Parsing operations
│   └── gc_benchmarks.rb         # GC-sensitive benchmarks
├── results/                  # JSON output (bench_*.json, gc_*.json, comparison_*.md)
├── mri/.tool-versions        # ruby 3.4.7
├── jruby/.tool-versions      # ruby jruby-10.0.2.0, java temurin-21.0.9+10.0.LTS
└── jruby17/.tool-versions    # ruby jruby-1.7.27, java corretto-8.472.08.1
```

## Setup

```bash
cd mri && asdf install
cd ../jruby && asdf install
cd ../jruby17 && asdf install
```

## Usage

```bash
./run_techniques_all.sh

# With custom iteration count
BENCH_ITERATIONS=5 ./run_techniques_all.sh
```

## Technique Comparisons

Compares different coding approaches that produce the **same result**:

| Category | Approaches Compared |
|----------|---------------------|
| String Building | `+`, `<<`, `concat`, `join`, `StringIO`, `each_with_object`, `inject`, interpolation |
| Array Iteration | `sum`, `reduce(:+)`, `reduce` block, `each`, `while`, `for` |
| Array Building | `Range#to_a`, `Array.new`, `map`, `<<`, `push`, `each_with_object` |
| Array Sorting | `sort`, `sort!`, `sort` block, `sort_by`, `sort_by identity` |
| Hash Building | `[]=` loop, `zip.to_h`, `each_with_object`, `map.to_h`, `Hash[]` |
| Hash Access | `[]`, `fetch`, `fetch` default, `\|\|` default, `dig` |
| Hash Key Iteration | `keys.map`, `map { \|k,_\| }`, `each_key.map`, `keys.each`, `each { \|k,_\| }` |
| Conditionals | ternary, `if/elsif`, `case/when`, hash lookup, array lookup |
| Loops | `while`, `times`, `upto`, `range.each`, `step`, `loop+break` |
| String Search | `include?`, `index`, `[]`, `match?`, `=~`, `start_with?` |
| Filtering | `select`, `select &:`, `reject`, `each + <<`, `partition`, `filter_map` |
| Transform | `map`, `map &proc`, `collect`, `each_with_object`, `inject` |
| Number Conversion | `map(&:to_i)`, `map { to_i }`, `Integer()`, `Integer(s,10)` |
| Nil Handling | `\|\|`, `nil?` ternary, `to_i`, `compact`, `nil? ? 0 : itself` |
| Object Duplication | `dup`, `clone`, `Hash[]`, `merge({})`, `to_h` |
| Method Invocation | `direct`, `send`, `public_send`, `method.call`, `__send__` |
| Block/Yield | `yield`, `block.call`, `proc.call`, `lambda.call`, unused closure overhead |
| Eval | `eval`, `instance_eval`, `class_eval`, `binding.eval`, string vs block |
| Caller | `caller()`, `caller(0)`, `caller(0, 1)`, `caller_locations` |
| Marshal | `dump/load` small, medium, dump only, load only |
| Memoization | `\|\|=`, `fetch` block, `key?` + `[]=`, ivar `\|\|=` |
| Set vs Array | `Array#include?` vs `Set.new+include?` vs reused Set |
| Mutex | no sync, `synchronize`, `lock/unlock`, `try_lock` |
| Thread-local | `Thread.current[]`, ivar, local var |

## Operation Benchmarks

Tests different operations (not comparing approaches). Hash operations use **string keys** for fair comparison across implementations.

- **String**: split, gsub, scan, match, encoding, frozen
- **Array**: creation, push, unshift, each, map, select, reduce, sort, flatten, compact, uniq, include?, index
- **Hash**: creation, read, write, each, keys/values, merge, map keys/values, select, nested access
- **Hash (regression tests)**: 500k int keys, 10k int keys x50, Hash#keys 500k, Java HashMap (JRuby only)
- **Parsing**: JSON, CSV, Integer, Float, Date, Regex, tokenization

## Output

Results saved to `results/bench_{mri,jruby10,jruby1}_TIMESTAMP.json`:

```json
{
  "metadata": { "ruby_engine": "ruby", "ruby_version": "...", "iterations": 3 },
  "techniques": [ { "name": "STR: << shovel", "time": { "avg": 0.0012 }, "gc": {...} } ],
  "operations": [ { "name": "String#split", "time": { "avg": 3.5 }, "gc": {...} } ]
}
```

## Adding Benchmarks

1. Add technique comparisons to `benchmarks/technique_benchmarks.rb`
2. Add operation benchmarks to the appropriate `benchmarks/*_benchmarks.rb` file

## Ruby Version Compatibility

Benchmarks use native implementations only - no polyfills. Features unavailable in older Ruby versions are automatically skipped:

| Feature | Required Ruby | Skipped on JRuby 1.7 |
|---------|--------------|---------------------|
| `Array#sum` | 2.4+ | Yes |
| `Object#itself` | 2.2+ | Yes |
| `Array#to_h` | 2.1+ | Yes |
| `Hash#dig` | 2.3+ | Yes |
| `String#match?` | 2.4+ | Yes |
| `Enumerable#filter_map` | 2.7+ | Yes |

This ensures benchmarks reflect true native performance of each Ruby version.

## Key Findings

### Closure Creation Overhead

When a block is passed to a method but never called, there is still overhead from closure creation:

| Pattern | MRI | JRuby 10 | JRuby 1.7 |
|---------|----:|--------:|----------:|
| No block (baseline) | - | - | - |
| `def foo; yield; end` (never yields) | +26% | +350% | +82% |
| `def foo(&block); end` (never calls) | +68% | +343% | +266% |

**Takeaways:**

- **MRI**: `yield` syntax is cheaper than `&block` for unused closures
- **JRuby 10**: JIT optimizes both patterns equally well
- **JRuby 1.7**: `&block` has significantly higher overhead

### JRuby 10 Large Hash Regression

JRuby 10 shows significant performance regressions with large hashes. See [jruby/jruby#9113](https://github.com/jruby/jruby/issues/9113).

**Hash#[]= (write) regression by key type:**

| Key Type | MRI | JRuby 1.7 | JRuby 10 | JRuby 10 vs 1.7 |
|----------|----:|----------:|---------:|----------------:|
| integer | 0.04s | 0.03s | 0.27s | **~8-10x slower** |
| dynamic string | 0.20s | 0.58s | 0.71s | ~1.2x slower |
| symbol | 0.53s | 0.83s | 0.89s | ~1.1x slower |
| **frozen string** | 0.06s | 0.42s | 0.34s | **1.25x faster** ✓ |
| 10k int x50 | 0.03s | 0.03s | 0.05s | none |
| Java HashMap | - | 0.05s | 0.02s | - |

**Hash#keys regression (scales with size, integer keys):**

| Entries | MRI | JRuby 1.7 | JRuby 10 | JRuby 10 vs 1.7 |
|--------:|----:|----------:|---------:|----------------:|
| 1k | 0.01ms | 0.08ms | 0.09ms | ~1x |
| 10k | 0.01ms | 0.12ms | 0.14ms | ~1.1x |
| 100k | 0.13ms | 0.55ms | 1.24ms | **2.3x** |
| 500k | 0.34ms | 5.0ms | 31.5ms | **6.3x** |

**Key observations:**

- **Frozen string keys are NOT affected** - actually 1.25x faster on JRuby 10
- Integer keys show the largest regression (~8-10x)
- Java HashMap is fast on JRuby 10, confirming the issue is in RubyHash implementation
- Small hashes (10k keys) are unaffected
- Regression scales with hash size - worse for larger hashes

Reproducer: run `benchmarks/hash_benchmarks.rb` and compare `Hash#[]= 500k int keys` vs `Java HashMap 500k int keys` on JRuby.

### JVM Garbage Collector Impact

The choice of JVM garbage collector has a **massive impact** on JRuby 10 performance for large data structures. See [jruby/jruby#9114](https://github.com/jruby/jruby/issues/9114).

**Hash#keys (500k entries) by GC:**

| GC | Time | vs MRI | vs G1 |
|----|-----:|-------:|------:|
| MRI 3.4.7 | 0.0004s | baseline | - |
| Shenandoah | 0.0014s | 3x slower | **8x faster** |
| ZGC | 0.0017s | 4x slower | **7x faster** |
| G1 (default) | 0.011s | 25x slower | baseline |
| Parallel | 0.019s | 43x slower | 0.6x slower |

**Recommendation for JRuby 10:**

```bash
# Use Shenandoah (best) or ZGC for workloads with large data structures
export JRUBY_OPTS="-J-XX:+UseShenandoahGC"
# or
export JRUBY_OPTS="-J-XX:+UseZGC"
```

Run `./run_gc_comparison.sh` to test GC impact on your system.

### Open JRuby Issues

Performance issues we've reported to the JRuby project:

| Issue | Summary | Status |
|-------|---------|--------|
| [#9113](https://github.com/jruby/jruby/issues/9113) | Hash#[]= 8-10x slower with integer keys | Targeted for 10.0.3.0 |
| [#9114](https://github.com/jruby/jruby/issues/9114) | Hash#keys 22x slower (mitigated by Shenandoah GC) | Under investigation |
| [#9115](https://github.com/jruby/jruby/issues/9115) | String-based eval 7-13x regression vs JRuby 1.7 | Expected (architectural) |
| [#9116](https://github.com/jruby/jruby/issues/9116) | Array#include? 3x regression vs JRuby 1.7 | Fix identified |
| [#9129](https://github.com/jruby/jruby/issues/9129) | String encoding conversion 4.3x regression | Open |
| [#9130](https://github.com/jruby/jruby/issues/9130) | Line-by-line parsing 3.6x regression | Open |
| [#9131](https://github.com/jruby/jruby/issues/9131) | Float() parsing 2x regression | Open |
| [#9132](https://github.com/jruby/jruby/issues/9132) | Integer() parsing 1.9x regression | Open |
| [#9133](https://github.com/jruby/jruby/issues/9133) | CSV.parse 1.8x regression | Open |
| [#9134](https://github.com/jruby/jruby/issues/9134) | String#scan tokenization 1.5x regression | Open |
| [#9135](https://github.com/jruby/jruby/issues/9135) | Range#to_a 3.25x regression | Open |
| [#9136](https://github.com/jruby/jruby/issues/9136) | Marshal.load 2.9x regression | Open |

### Universal Best Practices

These techniques are fastest across all Ruby implementations:

| Category | Best Technique |
|----------|----------------|
| String Building | `Array#join` |
| Array Building | `Range#to_a` |
| Array Sorting | `sort!` |
| String Search | `start_with?` |
| Number Conversion | `map(&:to_i)` |
| Object Duplication | `to_h` |
| Method Invocation | direct call |
| Block/Yield | `each { }` |
| Hash Key Iteration | `keys.map` |

See `results/comparison_*.md` for detailed comparisons.
