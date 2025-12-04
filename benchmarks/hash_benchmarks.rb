# encoding: utf-8
# frozen_string_literal: true

require_relative '../lib/benchmark_runner'

module HashBenchmarks
  extend self

  def run_all(options = {})
    iterations = options[:iterations] || 10
    results = []

    puts "\n#{'='*70}"
    puts "HASH BENCHMARKS - #{BenchmarkRunner.ruby_version_info}"
    puts "#{'='*70}"

    results << hash_creation_literal(:iterations => iterations)
    results << hash_creation_new(:iterations => iterations)
    results << hash_access(:iterations => iterations)
    results << hash_write(:iterations => iterations)
    results << hash_write_int_large(:iterations => iterations)
    results << hash_write_string_large(:iterations => iterations)
    results << hash_write_frozen_string_large(:iterations => iterations)
    results << hash_write_symbol_large(:iterations => iterations)
    results << hash_write_int_small(:iterations => iterations)
    # Java HashMap comparison - only on JRuby
    if RUBY_ENGINE == 'jruby'
      results << hash_java_hashmap(:iterations => iterations)
    end
    results << hash_each(:iterations => iterations)
    results << hash_keys_values(:iterations => iterations)
    results << hash_keys_large(:iterations => iterations)
    results << hash_merge(:iterations => iterations)
    results << hash_map_keys(:iterations => iterations)
    results << hash_map_values(:iterations => iterations)
    results << hash_select(:iterations => iterations)
    results << hash_nested_access(:iterations => iterations)
    results << hash_to_a(:iterations => iterations)
    results << hash_deep_nesting(:iterations => iterations)

    results
  end

  def hash_creation_literal(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Hash creation (literal)", :iterations => iterations) do
      100_000.times do
        { :a => 1, :b => 2, :c => 3, :d => 4, :e => 5, :f => 6, :g => 7, :h => 8, :i => 9, :j => 10 }
      end
    end
  end

  def hash_creation_new(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Hash creation (from array)", :iterations => iterations) do
      10_000.times do
        Hash[(1..100).map { |i| [i, i * 2] }]
      end
    end
  end

  def hash_access(options = {})
    iterations = options[:iterations] || 10
    hash = Hash[(1..10_000).map { |i| [i, "value_#{i}"] }]

    BenchmarkRunner.run(:name => "Hash#[] (read)", :iterations => iterations) do
      1_000_000.times { hash[rand(10_000) + 1] }
    end
  end

  def hash_write(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Hash#[]= (write)", :iterations => iterations) do
      hash = {}
      500_000.times { |i| hash[i] = i * 2 }
    end
  end

  # Large hash with integer keys - isolates JRuby 10 regression
  def hash_write_int_large(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Hash#[]= 500k int keys", :iterations => iterations) do
      hash = {}
      500_000.times { |i| hash[i] = i }
    end
  end

  # Large hash with string keys for comparison
  def hash_write_string_large(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Hash#[]= 500k string keys", :iterations => iterations) do
      hash = {}
      500_000.times { |i| hash["key#{i}"] = i }
    end
  end

  # Large hash with frozen string keys - common real-world pattern
  def hash_write_frozen_string_large(options = {})
    iterations = options[:iterations] || 10
    # Pre-create frozen keys (simulates real-world usage with constants/frozen literals)
    keys = (0...500_000).map { |i| "key#{i}".freeze }
    BenchmarkRunner.run(:name => "Hash#[]= 500k frozen string keys", :iterations => iterations) do
      hash = {}
      keys.each_with_index { |k, i| hash[k] = i }
    end
  end

  # Large hash with symbol keys
  def hash_write_symbol_large(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Hash#[]= 500k symbol keys", :iterations => iterations) do
      hash = {}
      500_000.times { |i| hash[:"key#{i}"] = i }
    end
  end

  # Small hash repeated - should be fast on all implementations
  def hash_write_int_small(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Hash#[]= 10k int keys x50", :iterations => iterations) do
      50.times do
        hash = {}
        10_000.times { |i| hash[i] = i }
      end
    end
  end

  # Java HashMap comparison - shows JRuby's underlying Java is fast
  # This benchmark only runs on JRuby
  def hash_java_hashmap(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Java HashMap 500k int keys", :iterations => iterations) do
      map = java.util.HashMap.new
      500_000.times { |i| map.put(i, i) }
    end
  end

  def hash_each(options = {})
    iterations = options[:iterations] || 10
    hash = Hash[(1..50_000).map { |i| [i, i * 2] }]

    BenchmarkRunner.run(:name => "Hash#each", :iterations => iterations) do
      sum = 0
      50.times { hash.each { |k, v| sum += v } }
    end
  end

  def hash_keys_values(options = {})
    iterations = options[:iterations] || 10
    hash = Hash[(1..100_000).map { |i| [i, i * 2] }]

    BenchmarkRunner.run(:name => "Hash#keys and Hash#values", :iterations => iterations) do
      100.times do
        hash.keys
        hash.values
      end
    end
  end

  # Large hash keys - isolates JRuby 10 regression (scales with hash size)
  def hash_keys_large(options = {})
    iterations = options[:iterations] || 10
    hash = Hash[(1..500_000).map { |i| [i, i] }]

    BenchmarkRunner.run(:name => "Hash#keys 500k", :iterations => iterations) do
      100.times { hash.keys }
    end
  end

  def hash_merge(options = {})
    iterations = options[:iterations] || 10
    h1 = Hash[(1..5_000).map { |i| [i, i] }]
    h2 = Hash[(5_001..10_000).map { |i| [i, i] }]

    BenchmarkRunner.run(:name => "Hash#merge", :iterations => iterations) do
      1000.times { h1.merge(h2) }
    end
  end

  # Ruby 1.9 compatible version of transform_keys
  def hash_map_keys(options = {})
    iterations = options[:iterations] || 10
    hash = Hash[(1..10_000).map { |i| [i, i * 2] }]

    BenchmarkRunner.run(:name => "Hash map keys", :iterations => iterations) do
      100.times do
        result = {}
        hash.each { |k, v| result[k.to_s] = v }
        result
      end
    end
  end

  # Ruby 1.9 compatible version of transform_values
  def hash_map_values(options = {})
    iterations = options[:iterations] || 10
    hash = Hash[(1..10_000).map { |i| [i, i] }]

    BenchmarkRunner.run(:name => "Hash map values", :iterations => iterations) do
      100.times do
        result = {}
        hash.each { |k, v| result[k] = v * 2 }
        result
      end
    end
  end

  def hash_select(options = {})
    iterations = options[:iterations] || 10
    hash = Hash[(1..50_000).map { |i| [i, i] }]

    BenchmarkRunner.run(:name => "Hash#select", :iterations => iterations) do
      50.times { hash.select { |k, v| v.even? } }
    end
  end

  def hash_nested_access(options = {})
    iterations = options[:iterations] || 10
    nested = {}
    1_000.times do |i|
      nested[i] = {}
      10.times do |j|
        nested[i][j] = { :value => i * j }
      end
    end

    BenchmarkRunner.run(:name => "Nested hash access", :iterations => iterations) do
      1_000_000.times do
        i = rand(1000)
        j = rand(10)
        nested[i][j][:value]
      end
    end
  end

  def hash_to_a(options = {})
    iterations = options[:iterations] || 10
    hash = Hash[(1..50_000).map { |i| [i, i * 2] }]

    BenchmarkRunner.run(:name => "Hash#to_a", :iterations => iterations) do
      100.times { hash.to_a }
    end
  end

  def hash_deep_nesting(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Deep hash tree creation", :iterations => iterations) do
      100.times do
        root = {}
        current = root
        50.times do |level|
          current[:children] = {}
          10.times do |child|
            current[:children][child] = { :level => level, :value => level * child }
          end
          current = current[:children][0]
        end
      end
    end
  end
end

if __FILE__ == $0
  HashBenchmarks.run_all.each do |result|
    puts result.to_h.to_json
  end
end
