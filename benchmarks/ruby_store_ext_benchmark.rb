# encoding: utf-8
# frozen_string_literal: true

# Benchmark: RubyStoreExt (native JRuby extension) vs Ruby Hash
# RubyStoreExt is a high-performance key-value store that beats JRuby Hash

unless RUBY_ENGINE == 'jruby'
  puts "This benchmark requires JRuby"
  exit 1
end

require_relative '../lib/benchmark_runner'
require 'java'

# Load RubyStoreExt
$CLASSPATH << File.expand_path('../../java/ruby_store_ext.jar', __FILE__)
Java::Default::RubyStoreExt.define(org.jruby.Ruby.getGlobalRuntime)

module RubyStoreExtBenchmark
  extend self

  def create_test_data(size = 100_000)
    @size = size
    @keys = (0...size).map { |i| "key#{i}" }
    @values = (0...size).to_a

    @hash = {}
    @keys.each_with_index { |k, i| @hash[k] = @values[i] }

    @store = RubyStoreExt.new(@size)
    @keys.each_with_index { |k, i| @store[k] = @values[i] }
  end

  def warmup_jit(iterations = 100)
    puts "Warming up JIT (#{iterations} iterations)..."
    iterations.times do
      @hash.each { |k, v| v }
      @store.each { |k, v| v }
      @hash.each_key { |k| k }
      @store.each_key { |k| k }
      @hash.each_value { |v| v }
      @store.each_value { |v| v }
      @hash.map { |k, v| v }
      @store.map { |k, v| v }
      1000.times { |i| @hash[@keys[i]]; @store[@keys[i]] }
    end
  end

  def run_all(iterations = 5)
    create_test_data
    warmup_jit

    puts "\n#{'=' * 70}"
    puts "RUBYSTOREEXT vs HASH BENCHMARK"
    puts BenchmarkRunner.ruby_version_info
    puts "Test size: #{@size} entries, #{iterations} iterations"
    puts "#{'=' * 70}"

    results = []

    puts "\n--- CORE ACCESS ---"
    results += benchmark_access(iterations)

    puts "\n--- ITERATION ---"
    results += benchmark_iteration(iterations)

    puts "\n--- KEYS/VALUES ---"
    results += benchmark_keys_values(iterations)

    puts "\n--- MODIFICATION ---"
    results += benchmark_modification(iterations)

    puts "\n--- CONVERSION ---"
    results += benchmark_conversion(iterations)

    print_summary(results)
  end

  def benchmark_access(iterations)
    n = 100_000
    [
      BenchmarkRunner.run(name: "Hash [] read", iterations: iterations) {
        sum = 0
        n.times { |i| sum += @hash[@keys[i % @size]] }
        sum
      },
      BenchmarkRunner.run(name: "Store [] read", iterations: iterations) {
        sum = 0
        n.times { |i| sum += @store[@keys[i % @size]] }
        sum
      },
      BenchmarkRunner.run(name: "Hash []= write", iterations: iterations) {
        h = {}
        n.times { |i| h[@keys[i % @size]] = i }
        h.size
      },
      BenchmarkRunner.run(name: "Store []= write", iterations: iterations) {
        s = RubyStoreExt.new(n)
        n.times { |i| s[@keys[i % @size]] = i }
        s.size
      },
      BenchmarkRunner.run(name: "Hash key?", iterations: iterations) {
        count = 0
        n.times { |i| count += 1 if @hash.key?(@keys[i % @size]) }
        count
      },
      BenchmarkRunner.run(name: "Store key?", iterations: iterations) {
        count = 0
        n.times { |i| count += 1 if @store.key?(@keys[i % @size]) }
        count
      },
      BenchmarkRunner.run(name: "Hash fetch", iterations: iterations) {
        sum = 0
        n.times { |i| sum += @hash.fetch(@keys[i % @size]) }
        sum
      },
      BenchmarkRunner.run(name: "Store fetch", iterations: iterations) {
        sum = 0
        n.times { |i| sum += @store.fetch(@keys[i % @size]) }
        sum
      }
    ]
  end

  def benchmark_iteration(iterations)
    [
      BenchmarkRunner.run(name: "Hash each", iterations: iterations) {
        sum = 0
        @hash.each { |k, v| sum += v }
        sum
      },
      BenchmarkRunner.run(name: "Store each", iterations: iterations) {
        sum = 0
        @store.each { |k, v| sum += v }
        sum
      },
      BenchmarkRunner.run(name: "Hash each_key", iterations: iterations) {
        count = 0
        @hash.each_key { |k| count += 1 }
        count
      },
      BenchmarkRunner.run(name: "Store each_key", iterations: iterations) {
        count = 0
        @store.each_key { |k| count += 1 }
        count
      },
      BenchmarkRunner.run(name: "Hash each_value", iterations: iterations) {
        sum = 0
        @hash.each_value { |v| sum += v }
        sum
      },
      BenchmarkRunner.run(name: "Store each_value", iterations: iterations) {
        sum = 0
        @store.each_value { |v| sum += v }
        sum
      },
      BenchmarkRunner.run(name: "Hash map", iterations: iterations) {
        @hash.map { |k, v| v * 2 }
      },
      BenchmarkRunner.run(name: "Store map", iterations: iterations) {
        @store.map { |k, v| v * 2 }
      },
      BenchmarkRunner.run(name: "Hash select", iterations: iterations) {
        @hash.select { |k, v| v > 50_000 }
      },
      BenchmarkRunner.run(name: "Store select", iterations: iterations) {
        @store.select { |k, v| v > 50_000 }
      }
    ]
  end

  def benchmark_keys_values(iterations)
    [
      BenchmarkRunner.run(name: "Hash keys", iterations: iterations) {
        100.times { @hash.keys }
      },
      BenchmarkRunner.run(name: "Store keys", iterations: iterations) {
        100.times { @store.keys }
      },
      BenchmarkRunner.run(name: "Hash values", iterations: iterations) {
        100.times { @hash.values }
      },
      BenchmarkRunner.run(name: "Store values", iterations: iterations) {
        100.times { @store.values }
      },
      BenchmarkRunner.run(name: "Hash size", iterations: iterations) {
        sum = 0
        100_000.times { sum += @hash.size }
        sum
      },
      BenchmarkRunner.run(name: "Store size", iterations: iterations) {
        sum = 0
        100_000.times { sum += @store.size }
        sum
      }
    ]
  end

  def benchmark_modification(iterations)
    # Pre-create stores for fair comparison
    @store_for_delete = RubyStoreExt.new(@size)
    @keys.each_with_index { |k, i| @store_for_delete[k] = @values[i] }

    [
      BenchmarkRunner.run(name: "Hash delete", iterations: iterations) {
        10_000.times { |i| @hash.delete("nonexistent#{i}") }
      },
      BenchmarkRunner.run(name: "Store delete", iterations: iterations) {
        10_000.times { |i| @store_for_delete.delete("nonexistent#{i}") }
      },
      # Test clear on pre-created objects
      BenchmarkRunner.run(name: "Hash clear", iterations: iterations) {
        h = @hash.dup
        10.times {
          h.clear
          @keys.each_with_index { |k, i| h[k] = @values[i] }
        }
      },
      BenchmarkRunner.run(name: "Store clear", iterations: iterations) {
        s = RubyStoreExt.new(@size)
        @keys.each_with_index { |k, i| s[k] = @values[i] }
        10.times {
          s.clear
          @keys.each_with_index { |k, i| s[k] = @values[i] }
        }
      },
      # Test merge with a Hash (common use case)
      BenchmarkRunner.run(name: "Hash merge", iterations: iterations) {
        other = { x: 1, y: 2, z: 3 }
        100.times { @hash.merge(other) }
      },
      BenchmarkRunner.run(name: "Store merge", iterations: iterations) {
        other = { x: 1, y: 2, z: 3 }
        100.times { @store.merge(other) }
      }
    ]
  end

  def benchmark_conversion(iterations)
    [
      BenchmarkRunner.run(name: "Hash to_a", iterations: iterations) {
        50.times { @hash.to_a }
      },
      BenchmarkRunner.run(name: "Store to_a", iterations: iterations) {
        50.times { @store.to_a }
      },
      BenchmarkRunner.run(name: "Hash flatten", iterations: iterations) {
        50.times { @hash.flatten }
      },
      BenchmarkRunner.run(name: "Store flatten", iterations: iterations) {
        50.times { @store.flatten }
      },
      BenchmarkRunner.run(name: "Hash invert", iterations: iterations) {
        50.times { @hash.invert }
      },
      BenchmarkRunner.run(name: "Store invert", iterations: iterations) {
        50.times { @store.invert }
      },
      # Compare same-type copying (dup)
      BenchmarkRunner.run(name: "Hash dup", iterations: iterations) {
        50.times { @hash.dup }
      },
      BenchmarkRunner.run(name: "Store dup", iterations: iterations) {
        50.times { @store.dup }
      }
    ]
  end

  def print_summary(results)
    puts "\n#{'=' * 70}"
    puts "SUMMARY"
    puts "#{'=' * 70}"

    puts "\n| Method | Hash | Store | Winner | Factor |"
    puts "|--------|------|-------|--------|--------|"

    store_wins = 0
    hash_wins = 0

    results.each_slice(2) do |hash_result, store_result|
      next unless hash_result && store_result

      hash_name = hash_result.to_h[:name]
      method = hash_name.sub("Hash ", "")
      hash_time = hash_result.to_h[:time][:avg]
      store_time = store_result.to_h[:time][:avg]

      if hash_time <= store_time
        winner = "Hash"
        factor = store_time / hash_time
        hash_wins += 1
      else
        winner = "Store"
        factor = hash_time / store_time
        store_wins += 1
      end

      marker = factor >= 1.5 ? (winner == "Store" ? " **" : " !!") : ""
      puts "| %-14s | %.4fs | %.4fs | %-6s | %.2fx%s |" % [method, hash_time, store_time, winner, factor, marker]
    end

    puts "\n--- Results ---"
    puts "Store wins: #{store_wins}"
    puts "Hash wins: #{hash_wins}"
    puts "\n** = Store significantly faster (>1.5x)"
    puts "!! = Hash significantly faster (>1.5x) - needs investigation"
  end
end

if __FILE__ == $0
  iterations = (ENV['BENCH_ITERATIONS'] || 5).to_i
  RubyStoreExtBenchmark.run_all(iterations)
end
