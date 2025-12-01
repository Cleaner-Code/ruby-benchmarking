# encoding: utf-8
# frozen_string_literal: true

require_relative '../lib/benchmark_runner'

module ArrayBenchmarks
  extend self

  def run_all(options = {})
    iterations = options[:iterations] || 10
    results = []

    puts "\n#{'='*70}"
    puts "ARRAY BENCHMARKS - #{BenchmarkRunner.ruby_version_info}"
    puts "#{'='*70}"

    results << array_creation_literal(:iterations => iterations)
    results << array_creation_new(:iterations => iterations)
    results << array_push(:iterations => iterations)
    results << array_unshift(:iterations => iterations)
    results << array_each(:iterations => iterations)
    results << array_map(:iterations => iterations)
    results << array_select(:iterations => iterations)
    results << array_reduce(:iterations => iterations)
    results << array_sort(:iterations => iterations)
    results << array_sort_by(:iterations => iterations)
    results << array_flatten(:iterations => iterations)
    results << array_compact(:iterations => iterations)
    results << array_uniq(:iterations => iterations)
    results << array_include(:iterations => iterations)
    results << array_index(:iterations => iterations)

    results
  end

  def array_creation_literal(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Array creation (literal)", :iterations => iterations) do
      100_000.times { [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] }
    end
  end

  def array_creation_new(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Array creation (Array.new)", :iterations => iterations) do
      10_000.times { Array.new(1000) { |i| i } }
    end
  end

  def array_push(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Array#push (append)", :iterations => iterations) do
      arr = []
      500_000.times { |i| arr.push(i) }
    end
  end

  def array_unshift(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Array#unshift (prepend)", :iterations => iterations) do
      arr = []
      10_000.times { |i| arr.unshift(i) }
    end
  end

  def array_each(options = {})
    iterations = options[:iterations] || 10
    arr = (1..100_000).to_a

    BenchmarkRunner.run(:name => "Array#each", :iterations => iterations) do
      sum = 0
      100.times { arr.each { |x| sum += x } }
    end
  end

  def array_map(options = {})
    iterations = options[:iterations] || 10
    arr = (1..100_000).to_a

    BenchmarkRunner.run(:name => "Array#map", :iterations => iterations) do
      50.times { arr.map { |x| x * 2 } }
    end
  end

  def array_select(options = {})
    iterations = options[:iterations] || 10
    arr = (1..100_000).to_a

    BenchmarkRunner.run(:name => "Array#select", :iterations => iterations) do
      50.times { arr.select { |x| x.even? } }
    end
  end

  def array_reduce(options = {})
    iterations = options[:iterations] || 10
    arr = (1..100_000).to_a

    BenchmarkRunner.run(:name => "Array#reduce", :iterations => iterations) do
      100.times { arr.reduce(0) { |sum, x| sum + x } }
    end
  end

  def array_sort(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Array#sort", :iterations => iterations) do
      50.times do
        arr = (1..50_000).to_a.shuffle
        arr.sort
      end
    end
  end

  def array_sort_by(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Array#sort_by", :iterations => iterations) do
      50.times do
        arr = (1..50_000).map { |i| { :value => i, :key => rand } }
        arr.sort_by { |h| h[:key] }
      end
    end
  end

  def array_flatten(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Array#flatten", :iterations => iterations) do
      1000.times do
        arr = Array.new(100) { Array.new(100) { |i| i } }
        arr.flatten
      end
    end
  end

  def array_compact(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Array#compact", :iterations => iterations) do
      1000.times do
        arr = Array.new(10_000) { |i| i.even? ? i : nil }
        arr.compact
      end
    end
  end

  def array_uniq(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Array#uniq", :iterations => iterations) do
      100.times do
        arr = Array.new(50_000) { rand(10_000) }
        arr.uniq
      end
    end
  end

  def array_include(options = {})
    iterations = options[:iterations] || 10
    arr = (1..10_000).to_a

    BenchmarkRunner.run(:name => "Array#include?", :iterations => iterations) do
      100_000.times { arr.include?(rand(15_000)) }
    end
  end

  def array_index(options = {})
    iterations = options[:iterations] || 10
    arr = (1..10_000).to_a

    BenchmarkRunner.run(:name => "Array#index", :iterations => iterations) do
      100_000.times { arr.index(rand(15_000)) }
    end
  end
end

if __FILE__ == $0
  ArrayBenchmarks.run_all.each do |result|
    puts result.to_h.to_json
  end
end
