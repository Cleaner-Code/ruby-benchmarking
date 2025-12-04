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
├── lib/
│   ├── benchmark_runner.rb   # Core benchmarking library
│   └── ruby19_compat.rb      # Ruby 1.9.3 compatibility polyfills
├── benchmarks/
│   ├── technique_benchmarks.rb  # Compare different approaches (17 categories)
│   ├── string_benchmarks.rb     # String operations
│   ├── array_benchmarks.rb      # Array operations
│   ├── hash_benchmarks.rb       # Hash operations
│   └── parsing_benchmarks.rb    # Parsing operations
├── results/                  # JSON output (bench_mri_*.json, bench_jruby10_*.json, bench_jruby1_*.json)
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

## Operation Benchmarks

Tests different operations (not comparing approaches):

- **String**: split, gsub, scan, match, encoding, frozen
- **Array**: creation, push, unshift, each, map, select, reduce, sort, flatten, compact, uniq, include?, index
- **Hash**: creation, read, write (int/string keys, small/large), each, keys/values, merge, map keys/values, select, nested access
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

### JRuby 10 Hash#[]= Regression

JRuby 10 shows a significant performance regression when growing large hashes with integer keys:

| Benchmark | MRI | JRuby 10 | JRuby 1.7 | Regression |
|-----------|----:|--------:|----------:|----------:|
| 500k int keys | 0.04s | 0.31s | 0.03s | **~8-10x** |
| 500k string keys | 0.20s | 0.90s | 0.58s | ~1.6x |
| 10k keys x 50 | 0.03s | 0.06s | 0.03s | none |
| Java HashMap | - | 0.03s | 0.05s | - |

**Key observations:**

- Java HashMap is fast on JRuby 10, suggesting the issue is in RubyHash implementation
- Small hashes (10k keys) are unaffected
- Integer keys show the largest regression

Reproducer: run `benchmarks/hash_benchmarks.rb` and compare `Hash#[]= 500k int keys` vs `Java HashMap 500k int keys` on JRuby.

### Universal Best Practices

These techniques are fastest across all Ruby implementations:

| Category | Best Technique |
|----------|----------------|
| String Building | `Array#join` |
| Array Building | `Range#to_a` |
| String Search | `start_with?` |
| Number Conversion | `map(&:to_i)` |
| Object Duplication | `to_h` |
| Method Invocation | direct call |
| Block/Yield | `each { }` |

See `results/comparison_*.md` for detailed comparisons.
