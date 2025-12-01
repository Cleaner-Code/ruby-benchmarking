#!/usr/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

SCRIPT_DIR = File.dirname(File.expand_path(__FILE__))

require_relative 'lib/benchmark_runner'
require_relative 'benchmarks/technique_benchmarks'
require_relative 'benchmarks/string_benchmarks'
require_relative 'benchmarks/array_benchmarks'
require_relative 'benchmarks/hash_benchmarks'
require_relative 'benchmarks/parsing_benchmarks'
require 'json'
require 'fileutils'

class TechniqueSuite
  ITERATIONS = Integer(ENV['BENCH_ITERATIONS'] || 3)
  RESULTS_DIR = File.join(SCRIPT_DIR, 'results')

  # Technique comparison categories (for alternative approaches)
  TECHNIQUE_CATEGORIES = {
    'STR:' => 'String Building',
    'ITER:' => 'Array Iteration',
    'ARR:' => 'Array Building',
    'SORT:' => 'Array Sorting',
    'HASH:' => 'Hash Building',
    'ACCESS:' => 'Hash Access',
    'COND:' => 'Conditionals',
    'LOOP:' => 'Loops',
    'SEARCH:' => 'String Search',
    'FILTER:' => 'Filtering',
    'XFORM:' => 'Transform',
    'CONV:' => 'Number Conversion',
    'NIL:' => 'Nil Handling',
    'DUP:' => 'Object Duplication'
  }

  def initialize
    @technique_results = []
    @operation_results = []
    @timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
  end

  def run
    puts "=" * 70
    puts "RUBY BENCHMARK SUITE"
    puts "=" * 70
    puts "Ruby Engine: #{RUBY_ENGINE}"
    puts "Ruby Version: #{BenchmarkRunner.ruby_version_info}"
    puts "Platform: #{RUBY_PLATFORM}"
    puts "Iterations per test: #{ITERATIONS}"
    puts "=" * 70

    # Run technique comparisons (alternative approaches)
    @technique_results = TechniqueBenchmarks.run_all(:iterations => ITERATIONS)

    # Run operation benchmarks (standard operations)
    operation_modules = [
      StringBenchmarks,
      ArrayBenchmarks,
      HashBenchmarks,
      ParsingBenchmarks
    ]

    operation_modules.each do |mod|
      @operation_results.concat(mod.run_all(:iterations => ITERATIONS))
    end

    print_technique_summary
    print_operation_summary
    save_results
  end

  def print_technique_summary
    puts "\n#{'=' * 95}"
    puts "TECHNIQUE COMPARISON SUMMARY (Best Approaches)"
    puts "#{'=' * 95}"

    TECHNIQUE_CATEGORIES.each do |prefix, category_name|
      category_results = @technique_results.select { |r| r.name.start_with?(prefix) }
      next if category_results.empty?

      puts "\n#{category_name}:"
      puts "-" * 70

      sorted = category_results.sort_by(&:avg_time)
      fastest = sorted.first.avg_time

      sorted.each_with_index do |r, i|
        ratio = r.avg_time / fastest
        winner = i == 0 ? " << FASTEST" : ""
        short_name = r.name.sub(/^[A-Z]+:\s*/, '')

        gc_count = r.gc_stats[:collections] || 0
        allocs = if RUBY_ENGINE == 'jruby'
                   r.gc_stats[:heap_used_bytes_after] || 0
                 else
                   r.gc_stats[:objects_allocated] || 0
                 end

        printf "  %-25s %9.4fs (%5.2fx) GC:%-4d %s%s\n",
               short_name[0..24], r.avg_time, ratio, gc_count,
               format_alloc(allocs), winner
      end
    end
  end

  def print_operation_summary
    puts "\n#{'=' * 95}"
    puts "OPERATION BENCHMARK SUMMARY"
    puts "#{'=' * 95}"

    alloc_label = RUBY_ENGINE == 'jruby' ? "Heap Used" : "Obj Allocated"
    printf "%-35s %10s %8s %10s %14s\n", "Benchmark", "Time (s)", "GC", "Mem Δ (MB)", alloc_label
    puts "-" * 95

    @operation_results.each do |r|
      gc_count = r.gc_stats[:collections] || 0
      mem_delta = r.memory_stats[:rss_mb_delta] || r.memory_stats[:used_mb_delta] || 0

      allocs = if RUBY_ENGINE == 'jruby'
                 r.gc_stats[:heap_used_bytes_after] || r.allocation_stats[:eden_peak_bytes] || 0
               else
                 r.gc_stats[:objects_allocated] || 0
               end

      printf "%-35s %10.4f %8d %10.2f %14s\n",
             r.name[0..34], r.avg_time, gc_count, mem_delta, format_alloc(allocs)
    end

    puts "\nTotal operation benchmarks: #{@operation_results.size}"
  end

  def format_alloc(n)
    return "-" if n == 0
    if RUBY_ENGINE == 'jruby'
      if n >= 1_048_576
        "#{(n / 1_048_576.0).round(1)}MB"
      elsif n >= 1_024
        "#{(n / 1_024.0).round(1)}KB"
      else
        "#{n}B"
      end
    else
      if n >= 1_000_000
        "#{(n / 1_000_000.0).round(1)}M"
      elsif n >= 1_000
        "#{(n / 1_000.0).round(1)}K"
      else
        n.to_s
      end
    end
  end

  def save_results
    FileUtils.mkdir_p(RESULTS_DIR)

    engine = if RUBY_ENGINE == 'jruby'
               # Include JRuby major version to distinguish 1.7 from 10.x
               major_version = defined?(JRUBY_VERSION) ? JRUBY_VERSION.split('.').first : 'x'
               "jruby#{major_version}"
             else
               'mri'
             end
    filename = File.join(RESULTS_DIR, "bench_#{engine}_#{@timestamp}.json")

    all_results = @technique_results + @operation_results

    output = {
      metadata: {
        ruby_engine: RUBY_ENGINE,
        ruby_version: BenchmarkRunner.ruby_version_info,
        platform: RUBY_PLATFORM,
        timestamp: @timestamp,
        iterations: ITERATIONS
      },
      techniques: @technique_results.map(&:to_h),
      operations: @operation_results.map(&:to_h),
      benchmarks: all_results.map(&:to_h)
    }

    File.write(filename, JSON.pretty_generate(output))
    puts "\n\nResults saved to: #{filename}"

    filename
  end
end

if __FILE__ == $0
  TechniqueSuite.new.run
end
