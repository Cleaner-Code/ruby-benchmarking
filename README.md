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
│   ├── technique_benchmarks.rb  # Compare different approaches (14 categories)
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

## Operation Benchmarks

Tests different operations (not comparing approaches):

- **String**: split, gsub, scan, match, encoding, frozen
- **Array**: creation, push, unshift, each, map, select, reduce, sort, flatten, compact, uniq, include?, index
- **Hash**: creation, read, write, each, keys/values, merge, map keys/values, select, nested access
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
