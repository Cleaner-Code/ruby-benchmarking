#!/usr/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'json'

class BenchmarkComparator
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

  def initialize(files)
    @results = files.map do |f|
      data = JSON.parse(File.read(f))
      {
        :file => f,
        :data => data,
        :name => short_name(data['metadata']['ruby_version']),
        :full_name => data['metadata']['ruby_version']
      }
    end
    @col_width = 12
  end

  def short_name(version)
    if version.include?('JRuby 1.7')
      'JRuby1.7'
    elsif version.include?('JRuby')
      'JRuby10'
    else
      'MRI'
    end
  end

  def compare
    puts "=" * 120
    puts "BENCHMARK COMPARISON: #{@results.map { |r| r[:name] }.join(' vs ')}"
    puts "=" * 120
    puts
    @results.each { |r| puts "#{r[:name].ljust(10)}: #{r[:full_name]}" }

    @summary = {}
    @results.each { |r| @summary[r[:name]] = { :technique_wins => 0, :op_wins => 0, :best_technique => 0 } }

    compare_techniques
    compare_operations
    print_summary
    print_recommendations
  end

  private

  def compare_techniques
    techniques_by_result = @results.map { |r| r[:data]['techniques'] || [] }
    return if techniques_by_result.all?(&:empty?)

    puts "\n#{'=' * 120}"
    puts "TECHNIQUE COMPARISONS (Best Approaches)"
    puts "=" * 120

    TECHNIQUE_CATEGORIES.each do |prefix, category_name|
      compare_technique_category(prefix, category_name, techniques_by_result)
    end
  end

  def compare_technique_category(prefix, category_name, techniques_by_result)
    # Get results for each Ruby version
    results_per_ruby = techniques_by_result.map { |t| t.select { |b| b['name'].start_with?(prefix) } }
    return if results_per_ruby.all?(&:empty?)

    puts "\n--- #{category_name} ---"

    # Header
    header = "%-26s" % "Technique"
    @results.each { |r| header += " %#{@col_width}s" % r[:name] }
    header += "  Winner"
    puts header
    puts "-" * (28 + (@col_width + 1) * @results.size + 10)

    # Get all technique names (union of all results)
    all_names = results_per_ruby.flatten.map { |b| b['name'] }.uniq

    # Calculate rankings per Ruby version
    rankings = results_per_ruby.map do |results|
      sorted = results.sort_by { |b| get_time(b) }
      sorted.each_with_index.to_h { |b, i| [b['name'], i + 1] }
    end

    # Find winner for each Ruby version
    winners = results_per_ruby.map do |results|
      next nil if results.empty?
      results.min_by { |b| get_time(b) }['name']
    end

    all_names.sort.each do |name|
      times = results_per_ruby.map do |results|
        bench = results.find { |b| b['name'] == name }
        bench ? get_time(bench) : nil
      end

      # Skip if no data
      next if times.compact.empty?

      # Find fastest
      valid_times = times.each_with_index.select { |t, _| t }.map { |t, i| [t, i] }
      fastest_idx = valid_times.min_by { |t, _| t }[1] if valid_times.any?

      short_name = name.sub(/^[A-Z]+:\s*/, '')
      row = "%-26s" % short_name[0..25]

      times.each_with_index do |time, i|
        if time.nil?
          row += " %#{@col_width}s" % "-"
        else
          rank = rankings[i][name]
          marker = (name == winners[i]) ? "*" : " "
          fast_marker = (i == fastest_idx) ? ">" : " "
          row += " %#{@col_width}s" % ("#{fast_marker}%.4f%s" % [time, marker])

          # Count wins
          if i == fastest_idx
            @summary[@results[i][:name]][:technique_wins] += 1
          end
        end
      end

      winner_name = fastest_idx ? @results[fastest_idx][:name] : "-"
      row += "  #{winner_name}"
      puts row
    end

    # Show best technique per Ruby
    best_line = "  >> Best: "
    winner_techniques = []
    winners.each_with_index do |w, i|
      next unless w
      winner_techniques << "#{@results[i][:name]}=#{w.sub(/^[A-Z]+:\s*/, '')}"
      @summary[@results[i][:name]][:best_technique] += 1
    end

    # Check if all agree
    unique_winners = winners.compact.uniq
    if unique_winners.size == 1
      puts "  >> ALL agree: #{unique_winners.first.sub(/^[A-Z]+:\s*/, '')}"
    else
      puts "  >> " + winner_techniques.join(" | ")
    end
  end

  def compare_operations
    ops_by_result = @results.map do |r|
      ops = r[:data]['operations'] || r[:data]['benchmarks'] || []
      ops.reject { |b| TECHNIQUE_CATEGORIES.keys.any? { |p| b['name'].start_with?(p) } }
    end
    return if ops_by_result.all?(&:empty?)

    puts "\n#{'=' * 120}"
    puts "OPERATION BENCHMARKS"
    puts "=" * 120

    # Header
    header = "%-30s" % "Benchmark"
    @results.each { |r| header += " %#{@col_width}s" % r[:name] }
    header += "  Winner   Factor"
    puts header
    puts "-" * 120

    # Get all operation names
    all_names = ops_by_result.flatten.map { |b| b['name'] }.uniq

    all_names.sort.each do |name|
      times = ops_by_result.map do |ops|
        bench = ops.find { |b| b['name'] == name }
        bench ? get_time(bench) : nil
      end

      next if times.compact.empty?

      valid_times = times.each_with_index.select { |t, _| t }.map { |t, i| [t, i] }
      fastest_idx = valid_times.min_by { |t, _| t }[1] if valid_times.any?
      slowest_time = valid_times.max_by { |t, _| t }[0] if valid_times.any?
      fastest_time = valid_times.min_by { |t, _| t }[0] if valid_times.any?

      row = "%-30s" % name[0..29]

      times.each_with_index do |time, i|
        if time.nil?
          row += " %#{@col_width}s" % "-"
        else
          marker = (i == fastest_idx) ? ">" : " "
          row += " %#{@col_width}s" % ("#{marker}%.4f" % time)

          if i == fastest_idx
            @summary[@results[i][:name]][:op_wins] += 1
          end
        end
      end

      winner_name = fastest_idx ? @results[fastest_idx][:name] : "-"
      factor = (fastest_time && slowest_time && fastest_time > 0) ? slowest_time / fastest_time : 1.0
      row += "  %-8s %5.1fx" % [winner_name, factor]
      puts row
    end

    print_gc_comparison(ops_by_result)
  end

  def print_gc_comparison(ops_by_result)
    puts "\n--- GC & Memory ---"

    header = "%-30s" % "Benchmark"
    @results.each { |r| header += " %#{@col_width}s" % "#{r[:name]} GC" }
    puts header
    puts "-" * (32 + (@col_width + 1) * @results.size)

    all_names = ops_by_result.flatten.map { |b| b['name'] }.uniq

    all_names.sort.each do |name|
      benches = ops_by_result.map { |ops| ops.find { |b| b['name'] == name } }
      next if benches.compact.empty?

      row = "%-30s" % name[0..29]
      benches.each do |bench|
        if bench.nil?
          row += " %#{@col_width}s" % "-"
        else
          gc = get_gc_count(bench)
          row += " %#{@col_width}d" % gc
        end
      end
      puts row
    end
  end

  def print_summary
    puts "\n#{'=' * 120}"
    puts "SUMMARY"
    puts "=" * 120

    puts "\nTechnique Comparisons (individual technique speed wins):"
    @results.each do |r|
      puts "  #{r[:name]}: #{@summary[r[:name]][:technique_wins]} wins"
    end

    puts "\nOperation Benchmarks (fastest implementation):"
    @results.each do |r|
      puts "  #{r[:name]}: #{@summary[r[:name]][:op_wins]} wins"
    end

    # Overall
    puts "\nOverall fastest (technique + operation wins):"
    totals = @results.map do |r|
      total = @summary[r[:name]][:technique_wins] + @summary[r[:name]][:op_wins]
      [r[:name], total]
    end.sort_by { |_, t| -t }

    totals.each { |name, total| puts "  #{name}: #{total} total wins" }
  end

  def print_recommendations
    techniques_by_result = @results.map { |r| r[:data]['techniques'] || [] }
    return if techniques_by_result.all?(&:empty?)

    puts "\n#{'=' * 120}"
    puts "OPTIMIZATION RECOMMENDATIONS"
    puts "=" * 120

    TECHNIQUE_CATEGORIES.each do |prefix, category_name|
      results_per_ruby = techniques_by_result.map { |t| t.select { |b| b['name'].start_with?(prefix) } }
      next if results_per_ruby.all?(&:empty?)

      winners = results_per_ruby.each_with_index.map do |results, i|
        next nil if results.empty?
        best = results.min_by { |b| get_time(b) }
        [best['name'].sub(/^[A-Z]+:\s*/, ''), @results[i][:name]]
      end.compact

      puts "\n#{category_name}:"

      unique_techniques = winners.map(&:first).uniq
      if unique_techniques.size == 1
        puts "  Use: #{unique_techniques.first}"
      else
        winners.each { |tech, ruby| puts "  #{ruby}: #{tech}" }
      end
    end
    puts
  end

  def get_time(bench)
    bench.dig('time', 'avg') || bench['avg_time'] || 0
  end

  def get_gc_count(bench)
    bench.dig('gc', 'collections') || 0
  end
end

if __FILE__ == $0
  if ARGV.size >= 2
    files = ARGV
  else
    # Auto-find latest results for each Ruby version
    mri = Dir['results/bench_mri_*.json'].sort.last
    jruby10 = Dir['results/bench_jruby10_*.json'].sort.last
    jruby17 = Dir['results/bench_jruby1_*.json'].sort.last

    files = [mri, jruby10, jruby17].compact

    if files.size < 2
      puts "Usage: ruby compare_techniques.rb <result1.json> <result2.json> [result3.json ...]"
      puts "   or: Run benchmarks for multiple Ruby versions first"
      puts
      puts "Found: #{files.join(', ')}"
      exit 1
    end
  end

  puts "Comparing: #{files.join(', ')}"
  puts

  comparator = BenchmarkComparator.new(files)
  comparator.compare
end
