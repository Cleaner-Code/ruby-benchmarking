#!/bin/bash
# Run GC-sensitive benchmarks with different JVM garbage collectors
# Outputs JSON results for comparison

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JAVA_HOME="${JAVA_HOME:-$HOME/.asdf/installs/java/temurin-21.0.9+10.0.LTS}"
JRUBY="$HOME/.asdf/installs/ruby/jruby-10.0.2.0/bin/ruby"
MRI="$HOME/.asdf/shims/ruby"

export BENCH_ITERATIONS="${BENCH_ITERATIONS:-3}"

echo "=== JVM Garbage Collector Benchmark Comparison ==="
echo "Iterations: $BENCH_ITERATIONS"
echo ""

# Run MRI baseline
echo ">>> Running MRI (baseline)..."
$MRI "$SCRIPT_DIR/run_gc_benchmarks.rb" mri
echo ""

# Run JRuby with different GCs
declare -a GCS=("G1GC:g1" "ParallelGC:parallel" "ZGC:zgc" "ShenandoahGC:shenandoah")

for gc_pair in "${GCS[@]}"; do
    gc_flag="${gc_pair%%:*}"
    gc_name="${gc_pair##*:}"

    echo ">>> Running JRuby 10 + $gc_flag..."
    JAVA_HOME="$JAVA_HOME" $JRUBY -J-XX:+Use${gc_flag} "$SCRIPT_DIR/run_gc_benchmarks.rb" "$gc_name"
    echo ""
done

echo "=== GC Comparison Complete ==="
echo ""
echo "Results saved to results/gc_*.json"
echo "Run 'ruby compare_gc.rb' to generate comparison report"
