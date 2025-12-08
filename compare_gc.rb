#!/usr/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

# Compare GC benchmark results across different garbage collectors
# Usage: ruby compare_gc.rb [results/gc_*.json ...]

require 'json'
require 'fileutils'

class GCComparison
  RESULTS_DIR = File.join(File.dirname(__FILE__), 'results')

  def initialize(files = nil)
    @files = files || find_latest_gc_results
    @results = load_results
  end

  def find_latest_gc_results
    pattern = File.join(RESULTS_DIR, 'gc_*.json')
    files = Dir.glob(pattern).sort

    # Group by date (YYYYMMDD part of timestamp)
    grouped = files.group_by { |f| f.match(/_(\d{8})_\d{6}\.json$/)[1] rescue nil }
    latest_date = grouped.keys.compact.max

    if latest_date
      # Get the most recent file for each GC type from that date
      date_files = grouped[latest_date]
      gc_types = {}
      date_files.sort.reverse.each do |f|
        # Extract gc type: gc_jruby10_g1_... or gc_mri_mri_...
        match = f.match(/gc_([^_]+)_([^_]+)_\d{8}/)
        if match
          key = "#{match[1]}_#{match[2]}"
          gc_types[key] ||= f # Keep first (most recent due to reverse sort)
        end
      end
      gc_types.values.sort
    else
      files.last(5) # Fallback to last 5 files
    end
  end

  def load_results
    @files.map do |file|
      data = JSON.parse(File.read(file))
      {
        :file => file,
        :gc => data['metadata']['gc'],
        :ruby => data['metadata']['ruby_version'],
        :benchmarks => data['benchmarks'].map { |b|
          { :name => b['name'], :time => b['time']['avg'] }
        }
      }
    end
  end

  def compare
    puts "Comparing: #{@files.join(', ')}"

    report = generate_report
    filename = save_report(report)

    puts report
    puts "\nReport saved to: #{filename}"
  end

  def generate_report
    lines = []
    lines << "# JVM Garbage Collector Comparison"
    lines << ""
    lines << "_Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}_"
    lines << ""

    # Versions
    lines << "## Configurations Tested"
    lines << ""
    @results.each do |r|
      lines << "- **#{r[:gc]}**: `#{r[:ruby]}`"
    end
    lines << ""

    # Find MRI baseline
    mri_result = @results.find { |r| r[:gc] == 'mri' }
    jruby_results = @results.reject { |r| r[:gc] == 'mri' }

    # Build benchmark comparison table
    lines << "## Benchmark Results"
    lines << ""

    # Get all benchmark names
    all_benchmarks = @results.flat_map { |r| r[:benchmarks].map { |b| b[:name] } }.uniq

    # Header
    gc_names = @results.map { |r| r[:gc] }
    header = "| Benchmark |"
    gc_names.each { |gc| header += " #{gc} |" }
    header += " Best | vs MRI |"
    lines << header

    separator = "|:----------|"
    gc_names.each { separator += "----------:|" }
    separator += ":------:|-------:|"
    lines << separator

    # Data rows
    all_benchmarks.each do |bench_name|
      row = "| #{bench_name.sub('GC: ', '')} |"

      times = {}
      @results.each do |r|
        bench = r[:benchmarks].find { |b| b[:name] == bench_name }
        time = bench ? bench[:time] : nil
        times[r[:gc]] = time
        row += time ? " #{format('%.4f', time)}s |" : " - |"
      end

      # Find best (excluding MRI for JRuby comparison)
      jruby_times = times.reject { |k, _| k == 'mri' }.compact
      best_gc = jruby_times.min_by { |_, v| v || Float::INFINITY }&.first || '-'
      row += " #{best_gc} |"

      # Factor vs MRI
      mri_time = times['mri']
      best_jruby_time = jruby_times.values.compact.min
      if mri_time && best_jruby_time
        factor = best_jruby_time / mri_time
        row += " #{format('%.1f', factor)}x |"
      else
        row += " - |"
      end

      lines << row
    end

    lines << ""

    # Summary
    lines << "## Summary"
    lines << ""

    if jruby_results.any?
      lines << "### Best GC per Benchmark"
      lines << ""

      wins = Hash.new(0)
      all_benchmarks.each do |bench_name|
        jruby_times = {}
        jruby_results.each do |r|
          bench = r[:benchmarks].find { |b| b[:name] == bench_name }
          jruby_times[r[:gc]] = bench[:time] if bench
        end
        best = jruby_times.min_by { |_, v| v || Float::INFINITY }&.first
        wins[best] += 1 if best
      end

      lines << "| GC | Wins |"
      lines << "|:---|-----:|"
      wins.sort_by { |_, v| -v }.each do |gc, count|
        lines << "| #{gc} | #{count} |"
      end
      lines << ""
    end

    # Recommendations
    lines << "## Recommendations"
    lines << ""
    lines << "Based on these results:"
    lines << ""

    if jruby_results.any?
      # Calculate average speedup for each GC vs G1
      g1_result = jruby_results.find { |r| r[:gc] == 'g1' }
      if g1_result
        speedups = {}
        jruby_results.each do |r|
          next if r[:gc] == 'g1'
          ratios = []
          all_benchmarks.each do |bench_name|
            g1_bench = g1_result[:benchmarks].find { |b| b[:name] == bench_name }
            other_bench = r[:benchmarks].find { |b| b[:name] == bench_name }
            if g1_bench && other_bench && g1_bench[:time] && other_bench[:time]
              ratios << g1_bench[:time] / other_bench[:time]
            end
          end
          speedups[r[:gc]] = ratios.sum / ratios.size if ratios.any?
        end

        best_gc = speedups.max_by { |_, v| v }
        if best_gc
          lines << "- **Recommended GC**: `#{best_gc[0]}` (#{format('%.1f', best_gc[1])}x faster than G1 on average)"
          lines << ""
          lines << "```bash"
          lines << "export JRUBY_OPTS=\"-J-XX:+Use#{best_gc[0].capitalize}GC\""
          lines << "```"
        end
      end
    end

    lines << ""
    lines.join("\n")
  end

  def save_report(report)
    FileUtils.mkdir_p(RESULTS_DIR)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    filename = File.join(RESULTS_DIR, "gc_comparison_#{timestamp}.md")
    File.write(filename, report)
    filename
  end
end

if __FILE__ == $0
  files = ARGV.empty? ? nil : ARGV
  GCComparison.new(files).compare
end
