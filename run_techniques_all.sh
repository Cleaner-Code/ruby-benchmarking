#!/bin/zsh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ITERATIONS=${BENCH_ITERATIONS:-3}

echo "Running benchmarks with $ITERATIONS iterations per test"
echo

echo "=========================================="
echo "Running MRI Ruby benchmarks..."
echo "=========================================="
cd "$SCRIPT_DIR/mri"
BENCH_ITERATIONS=$ITERATIONS ruby "$SCRIPT_DIR/run_techniques.rb"

echo
echo "=========================================="
echo "Running JRuby 10 benchmarks..."
echo "=========================================="
cd "$SCRIPT_DIR/jruby"
# Set JAVA_HOME for JRuby 10 (Temurin 21)
export JAVA_HOME="$HOME/.asdf/installs/java/temurin-21.0.9+10.0.LTS"
BENCH_ITERATIONS=$ITERATIONS ruby "$SCRIPT_DIR/run_techniques.rb"

echo
echo "=========================================="
echo "Running JRuby 1.7 benchmarks..."
echo "=========================================="
cd "$SCRIPT_DIR/jruby17"
# Set JAVA_HOME for JRuby 1.7 (Corretto 8)
export JAVA_HOME="$HOME/.asdf/installs/java/corretto-8.472.08.1"
BENCH_ITERATIONS=$ITERATIONS ruby "$SCRIPT_DIR/run_techniques.rb"

echo
echo "=========================================="
echo "Comparing all results..."
echo "=========================================="
cd "$SCRIPT_DIR"
MRI_RESULT=$(ls -t results/bench_mri_*.json 2>/dev/null | head -1)
JRUBY10_RESULT=$(ls -t results/bench_jruby10_*.json 2>/dev/null | head -1)
JRUBY17_RESULT=$(ls -t results/bench_jruby1_*.json 2>/dev/null | head -1)

# Build list of available results
RESULTS=""
[ -n "$MRI_RESULT" ] && RESULTS="$RESULTS $MRI_RESULT"
[ -n "$JRUBY10_RESULT" ] && RESULTS="$RESULTS $JRUBY10_RESULT"
[ -n "$JRUBY17_RESULT" ] && RESULTS="$RESULTS $JRUBY17_RESULT"

if [ -n "$RESULTS" ]; then
  ruby compare_techniques.rb $RESULTS
fi
