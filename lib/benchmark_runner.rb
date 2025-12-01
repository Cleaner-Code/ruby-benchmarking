# encoding: utf-8
# frozen_string_literal: true

require 'benchmark'
require 'json'
require_relative 'ruby19_compat'

module BenchmarkRunner
  WARMUP_ITERATIONS = 3

  # Helper to sum arrays - uses native sum when available, falls back to reduce
  def self.array_sum(arr)
    if HAS_ARRAY_SUM
      arr.sum
    else
      arr.reduce(0, :+)
    end
  end

  class Result
    attr_reader :name, :ruby_version, :times, :gc_stats, :memory_stats, :allocation_stats

    def initialize(options = {})
      @name = options[:name]
      @ruby_version = options[:ruby_version]
      @times = options[:times]
      @gc_stats = options[:gc_stats] || {}
      @memory_stats = options[:memory_stats] || {}
      @allocation_stats = options[:allocation_stats] || {}
    end

    def avg_time
      BenchmarkRunner.array_sum(@times) / @times.size.to_f
    end

    def min_time
      @times.min
    end

    def max_time
      @times.max
    end

    def std_dev
      avg = avg_time
      variance = @times.map { |t| (t - avg) ** 2 }
      Math.sqrt(BenchmarkRunner.array_sum(variance) / @times.size)
    end

    def to_h
      {
        :name => @name,
        :ruby_version => @ruby_version,
        :iterations => @times.size,
        :time => {
          :avg => avg_time,
          :min => min_time,
          :max => max_time,
          :std_dev => std_dev
        },
        :gc => @gc_stats,
        :memory => @memory_stats,
        :allocations => @allocation_stats
      }
    end
  end

  def self.ruby_version_info
    if RUBY_ENGINE == 'jruby'
      "JRuby #{JRUBY_VERSION} (#{RUBY_VERSION}) [#{java.lang.System.getProperty('java.version')}]"
    else
      "#{RUBY_ENGINE} #{RUBY_VERSION}p#{RUBY_PATCHLEVEL}"
    end
  end

  def self.get_time
    if HAS_CLOCK_MONOTONIC
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    else
      Time.now.to_f
    end
  end

  def self.get_memory_mb
    if RUBY_ENGINE == 'jruby'
      runtime = java.lang.Runtime.getRuntime
      {
        :used => (runtime.totalMemory - runtime.freeMemory) / 1024.0 / 1024.0,
        :total => runtime.totalMemory / 1024.0 / 1024.0,
        :max => runtime.maxMemory / 1024.0 / 1024.0
      }
    else
      rss = `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
      gc_stat = GC.stat
      {
        :rss_mb => rss,
        :heap_allocated_pages => gc_stat[:heap_allocated_pages],
        :heap_live_slots => gc_stat[:heap_live_slots],
        :heap_free_slots => gc_stat[:heap_free_slots],
        :malloc_increase_bytes => gc_stat[:malloc_increase_bytes]
      }
    end
  end

  def self.get_gc_stats
    if RUBY_ENGINE == 'jruby'
      gc_beans = java.lang.management.ManagementFactory.getGarbageCollectorMXBeans
      memory_bean = java.lang.management.ManagementFactory.getMemoryMXBean
      heap = memory_bean.getHeapMemoryUsage
      counts = gc_beans.map { |b| b.getCollectionCount }
      times = gc_beans.map { |b| b.getCollectionTime }
      {
        :count => array_sum(counts),
        :time_ms => array_sum(times),
        :heap_used_bytes => heap.getUsed,
        :heap_committed_bytes => heap.getCommitted
      }
    else
      stat = GC.stat
      {
        :count => stat[:count],
        :major_count => stat[:major_gc_count],
        :minor_count => stat[:minor_gc_count],
        :total_allocated_objects => stat[:total_allocated_objects],
        :total_freed_objects => stat[:total_freed_objects]
      }
    end
  end

  def self.get_allocations
    if RUBY_ENGINE == 'jruby'
      # Use memory pool stats as proxy for allocations
      pools = java.lang.management.ManagementFactory.getMemoryPoolMXBeans
      eden = pools.find { |p| p.getName.downcase.include?('eden') }
      {
        :eden_used => eden ? eden.getUsage.getUsed : 0,
        :eden_peak => eden ? eden.getPeakUsage.getUsed : 0
      }
    else
      counts = ObjectSpace.count_objects
      {
        :total => counts[:TOTAL],
        :free => counts[:FREE],
        :t_object => counts[:T_OBJECT],
        :t_string => counts[:T_STRING],
        :t_array => counts[:T_ARRAY],
        :t_hash => counts[:T_HASH]
      }
    end
  end

  def self.warmup(options = {}, &block)
    iterations = options[:iterations] || WARMUP_ITERATIONS
    iterations.times { block.call }
    GC.start
    GC.start  # Double GC for thoroughness
  end

  def self.run(options = {}, &block)
    name = options[:name]
    iterations = options[:iterations] || 10
    warmup_iterations = options[:warmup_iterations] || WARMUP_ITERATIONS

    puts "  Running: #{name}"

    # Warmup
    warmup({ :iterations => warmup_iterations }, &block)

    # Capture baseline stats
    GC.start
    gc_before = get_gc_stats
    mem_before = get_memory_mb
    alloc_before = get_allocations

    # Run benchmark
    times = []
    iterations.times do
      start = get_time
      block.call
      times << (get_time - start)
    end

    # Capture final stats
    gc_after = get_gc_stats
    mem_after = get_memory_mb
    alloc_after = get_allocations

    # Calculate deltas
    gc_stats = calculate_gc_delta(gc_before, gc_after)
    memory_stats = calculate_memory_delta(mem_before, mem_after)
    allocation_stats = calculate_allocation_delta(alloc_before, alloc_after)

    Result.new(
      :name => name,
      :ruby_version => ruby_version_info,
      :times => times,
      :gc_stats => gc_stats,
      :memory_stats => memory_stats,
      :allocation_stats => allocation_stats
    )
  end

  def self.calculate_gc_delta(before, after)
    if RUBY_ENGINE == 'jruby'
      {
        :collections => after[:count] - before[:count],
        :gc_time_ms => after[:time_ms] - before[:time_ms],
        :heap_used_bytes_after => after[:heap_used_bytes],
        :heap_committed_bytes => after[:heap_committed_bytes]
      }
    else
      {
        :collections => after[:count] - before[:count],
        :major_collections => after[:major_count] - before[:major_count],
        :minor_collections => after[:minor_count] - before[:minor_count],
        :objects_allocated => after[:total_allocated_objects] - before[:total_allocated_objects],
        :objects_freed => after[:total_freed_objects] - before[:total_freed_objects]
      }
    end
  end

  def self.calculate_memory_delta(before, after)
    if RUBY_ENGINE == 'jruby'
      {
        :used_mb_before => before[:used],
        :used_mb_after => after[:used],
        :used_mb_delta => after[:used] - before[:used],
        :total_mb => after[:total],
        :max_mb => after[:max]
      }
    else
      {
        :rss_mb_before => before[:rss_mb],
        :rss_mb_after => after[:rss_mb],
        :rss_mb_delta => after[:rss_mb] - before[:rss_mb],
        :heap_live_slots_delta => after[:heap_live_slots] - before[:heap_live_slots]
      }
    end
  end

  def self.calculate_allocation_delta(before, after)
    if RUBY_ENGINE == 'jruby'
      {
        :eden_delta_bytes => (after[:eden_used] || 0) - (before[:eden_used] || 0),
        :eden_peak_bytes => after[:eden_peak] || 0
      }
    else
      return {} if before.empty? || after.empty?
      {
        :total_delta => after[:total] - before[:total],
        :strings_delta => after[:t_string] - before[:t_string],
        :arrays_delta => after[:t_array] - before[:t_array],
        :hashes_delta => after[:t_hash] - before[:t_hash],
        :objects_delta => after[:t_object] - before[:t_object]
      }
    end
  end

  def self.compare(*results)
    puts "\n" + "=" * 70
    puts "COMPARISON: #{results.first.name}"
    puts "=" * 70

    results.sort_by { |r| r.avg_time }.each_with_index do |r, i|
      baseline = results.first.avg_time
      ratio = r.avg_time / baseline

      printf "  %-40s avg: %10.6fs  (%.2fx)\n",
             r.ruby_version[0..39], r.avg_time, ratio
    end
    puts
  end
end
