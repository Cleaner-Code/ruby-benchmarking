#!/usr/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

# Run GC-sensitive benchmarks
# Usage: ruby run_gc_benchmarks.rb [gc_name]
# The gc_name is used to tag the output file (e.g., g1, zgc, shenandoah)

SCRIPT_DIR = File.dirname(File.expand_path(__FILE__))

require_relative 'lib/benchmark_runner'
require_relative 'benchmarks/gc_benchmarks'
require 'json'
require 'fileutils'

class GCBenchmarkSuite
  ITERATIONS = Integer(ENV['BENCH_ITERATIONS'] || 3)
  RESULTS_DIR = File.join(SCRIPT_DIR, 'results')

  def initialize(gc_name = nil)
    @gc_name = gc_name || detect_gc
    @results = []
    @timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
  end

  def detect_gc
    if RUBY_ENGINE == 'jruby'
      # Try to detect GC from JVM
      begin
        gc_beans = java.lang.management.ManagementFactory.getGarbageCollectorMXBeans
        gc_names = gc_beans.map(&:getName).join(', ')
        if gc_names.include?('Shenandoah')
          'shenandoah'
        elsif gc_names.include?('ZGC')
          'zgc'
        elsif gc_names.include?('G1')
          'g1'
        elsif gc_names.include?('Parallel')
          'parallel'
        else
          'unknown'
        end
      rescue
        'unknown'
      end
    else
      'mri'
    end
  end

  def run
    puts "=" * 70
    puts "GC-SENSITIVE BENCHMARK SUITE"
    puts "=" * 70
    puts "Ruby Engine: #{RUBY_ENGINE}"
    puts "Ruby Version: #{BenchmarkRunner.ruby_version_info}"
    puts "GC: #{@gc_name}"
    puts "Iterations per test: #{ITERATIONS}"
    puts "=" * 70

    @results = GCBenchmarks.run_all(:iterations => ITERATIONS)

    print_summary
    save_results
  end

  def print_summary
    puts "\n#{'=' * 95}"
    puts "GC BENCHMARK SUMMARY (#{@gc_name})"
    puts "#{'=' * 95}"

    printf "%-30s %10s %8s %14s\n", "Benchmark", "Time (s)", "GC", "Heap"
    puts "-" * 70

    @results.each do |r|
      gc_count = r.gc_stats[:collections] || 0
      heap = r.gc_stats[:heap_used_bytes_after] || 0
      heap_str = heap > 0 ? "#{(heap / 1_048_576.0).round(1)}MB" : "-"

      printf "%-30s %10.4f %8d %14s\n",
             r.name[0..29], r.avg_time, gc_count, heap_str
    end

    puts "\nTotal benchmarks: #{@results.size}"
  end

  def save_results
    FileUtils.mkdir_p(RESULTS_DIR)

    engine = RUBY_ENGINE == 'jruby' ? 'jruby10' : 'mri'
    filename = File.join(RESULTS_DIR, "gc_#{engine}_#{@gc_name}_#{@timestamp}.json")

    output = {
      :metadata => {
        :ruby_engine => RUBY_ENGINE,
        :ruby_version => BenchmarkRunner.ruby_version_info,
        :gc => @gc_name,
        :platform => RUBY_PLATFORM,
        :timestamp => @timestamp,
        :iterations => ITERATIONS
      },
      :benchmarks => @results.map(&:to_h)
    }

    File.write(filename, JSON.pretty_generate(output))
    puts "\nResults saved to: #{filename}"

    filename
  end
end

if __FILE__ == $0
  gc_name = ARGV[0]
  GCBenchmarkSuite.new(gc_name).run
end
