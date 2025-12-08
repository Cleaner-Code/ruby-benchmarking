# encoding: utf-8
# frozen_string_literal: true

require_relative '../lib/benchmark_runner'

# GC-sensitive benchmarks for comparing JVM garbage collector impact
# These benchmarks are specifically chosen because they show significant
# performance differences between GC implementations.
module GCBenchmarks
  extend self

  def run_all(options = {})
    iterations = options[:iterations] || 5
    results = []

    puts "\n#{'=' * 70}"
    puts "GC-SENSITIVE BENCHMARKS - #{BenchmarkRunner.ruby_version_info}"
    puts "#{'=' * 70}"

    results.concat(hash_keys_benchmarks(iterations))
    results.concat(hash_write_benchmarks(iterations))
    results.concat(large_array_benchmarks(iterations))

    results
  end

  private

  # Hash#keys is heavily impacted by GC choice
  def hash_keys_benchmarks(iterations)
    puts "\n--- Hash#keys (GC-sensitive) ---"

    results = []

    # 500k entries - primary test case
    hash_500k = {}
    500_000.times { |i| hash_500k[i] = i }

    results << BenchmarkRunner.run(:name => "GC: Hash#keys 500k", :iterations => iterations) {
      10.times { hash_500k.keys }
    }

    # 100k entries
    hash_100k = {}
    100_000.times { |i| hash_100k[i] = i }

    results << BenchmarkRunner.run(:name => "GC: Hash#keys 100k", :iterations => iterations) {
      50.times { hash_100k.keys }
    }

    # 1M entries - stress test
    hash_1m = {}
    1_000_000.times { |i| hash_1m[i] = i }

    results << BenchmarkRunner.run(:name => "GC: Hash#keys 1M", :iterations => iterations) {
      5.times { hash_1m.keys }
    }

    results
  end

  # Hash#[]= with integer keys
  def hash_write_benchmarks(iterations)
    puts "\n--- Hash#[]= integer keys (GC-sensitive) ---"

    results = []

    results << BenchmarkRunner.run(:name => "GC: Hash#[]= 500k int", :iterations => iterations) {
      h = {}
      500_000.times { |i| h[i] = i }
    }

    results << BenchmarkRunner.run(:name => "GC: Hash#[]= 100k int x5", :iterations => iterations) {
      5.times do
        h = {}
        100_000.times { |i| h[i] = i }
      end
    }

    results
  end

  # Large array operations
  def large_array_benchmarks(iterations)
    puts "\n--- Large Array (GC-sensitive) ---"

    results = []

    arr_500k = (1..500_000).to_a

    results << BenchmarkRunner.run(:name => "GC: Array#dup 500k", :iterations => iterations) {
      10.times { arr_500k.dup }
    }

    results << BenchmarkRunner.run(:name => "GC: Array#map 500k", :iterations => iterations) {
      5.times { arr_500k.map { |x| x * 2 } }
    }

    results << BenchmarkRunner.run(:name => "GC: Array#select 500k", :iterations => iterations) {
      10.times { arr_500k.select { |x| x % 2 == 0 } }
    }

    results
  end
end
