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
    'HKEY:' => 'Hash Key Iteration',
    'COND:' => 'Conditionals',
    'LOOP:' => 'Loops',
    'SEARCH:' => 'String Search',
    'FILTER:' => 'Filtering',
    'XFORM:' => 'Transform',
    'CONV:' => 'Number Conversion',
    'NIL:' => 'Nil Handling',
    'DUP:' => 'Object Duplication',
    'CALL:' => 'Method Invocation',
    'BLOCK:' => 'Block/Yield',
    'EVAL:' => 'Eval',
    'CALLER:' => 'Caller',
    'MARSHAL:' => 'Marshal',
    'MEMO:' => 'Memoization',
    'SETARR:' => 'Set vs Array',
    'MUTEX:' => 'Mutex',
    'THREAD:' => 'Thread-local',
    'STRUCT:' => 'Data Structures',
    'YAML:' => 'YAML',
    'LAZY:' => 'Lazy Evaluation',
    'GROUP:' => 'Grouping',
    'META:' => 'Metaprogramming',
    'EXC:' => 'Exceptions',
    'FREEZE:' => 'String Freeze',
    'SPLIT:' => 'Split Patterns'
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
    @output = []
  end

  def short_name(version)
    if version.include?('JRuby 1.7')
      'JRuby 1.7'
    elsif version.include?('JRuby')
      'JRuby 10'
    elsif version.include?('truffleruby')
      'TruffleRuby'
    else
      'MRI'
    end
  end

  def compare
    @summary = {}
    @results.each { |r| @summary[r[:name]] = { :technique_wins => 0, :op_wins => 0, :best_technique => 0 } }

    write_header
    compare_techniques
    compare_operations
    write_summary
    write_recommendations

    @output.join("\n")
  end

  def save(filename)
    content = compare
    File.write(filename, content)
    puts "Report saved to: #{filename}"
    filename
  end

  private

  def out(line = "")
    @output << line
  end

  def write_header
    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    out "# Ruby Benchmark Comparison"
    out
    out "_Generated: #{timestamp}_"
    out
    out "## Versions Compared"
    out
    @results.each { |r| out "- **#{r[:name]}**: `#{r[:full_name]}`" }
    out
  end

  def compare_techniques
    techniques_by_result = @results.map { |r| r[:data]['techniques'] || [] }
    return if techniques_by_result.all?(&:empty?)

    out "## Technique Comparisons"
    out
    out "Format: **time** (gc, heap MB) | \\* = best for that Ruby"
    out

    TECHNIQUE_CATEGORIES.each do |prefix, category_name|
      compare_technique_category(prefix, category_name, techniques_by_result)
    end
  end

  def compare_technique_category(prefix, category_name, techniques_by_result)
    results_per_ruby = techniques_by_result.map { |t| t.select { |b| b['name'].start_with?(prefix) } }
    return if results_per_ruby.all?(&:empty?)

    out "### #{category_name}"
    out

    # Table header
    header = "| Technique |"
    separator = "|:----------|"
    @results.each do |r|
      header += " #{r[:name]} |"
      separator += "----------:|"
    end
    header += " Winner |"
    separator += ":------:|"
    out header
    out separator

    all_names = results_per_ruby.flatten.map { |b| b['name'] }.uniq

    rankings = results_per_ruby.map do |results|
      sorted = results.sort_by { |b| get_time(b) }
      sorted.each_with_index.to_h { |b, i| [b['name'], i + 1] }
    end

    winners = results_per_ruby.map do |results|
      next nil if results.empty?
      results.min_by { |b| get_time(b) }['name']
    end

    all_names.sort.each do |name|
      benches = results_per_ruby.map do |results|
        results.find { |b| b['name'] == name }
      end

      times = benches.map { |b| b ? get_time(b) : nil }
      next if times.compact.empty?

      valid_times = times.each_with_index.select { |t, _| t }.map { |t, i| [t, i] }
      fastest_idx = valid_times.min_by { |t, _| t }[1] if valid_times.any?

      short_name = name.sub(/^[A-Z]+:\s*/, '')
      # Escape pipe characters in technique names to avoid breaking markdown tables
      escaped_name = short_name.gsub('|', '\\|')
      row = "| #{escaped_name} |"

      benches.each_with_index do |bench, i|
        if bench.nil?
          row += " - |"
        else
          time = get_time(bench)
          gc = get_gc_count(bench)
          heap = get_heap_mb(bench)
          marker = (name == winners[i]) ? "\\*" : ""

          # Build info string
          info_parts = []
          info_parts << gc.to_s if gc > 0
          info_parts << "#{heap}MB" if heap > 0
          info_str = info_parts.empty? ? "" : " (#{info_parts.join(', ')})"

          time_str = "%.4f#{marker}#{info_str}" % time
          if i == fastest_idx
            row += " **#{time_str}** |"
            @summary[@results[i][:name]][:technique_wins] += 1
          else
            row += " #{time_str} |"
          end
        end
      end

      winner_name = fastest_idx ? @results[fastest_idx][:name] : "-"
      row += " #{winner_name} |"
      out row
    end

    # Best technique summary
    winner_techniques = []
    winners.each_with_index do |w, i|
      next unless w
      technique_name = w.sub(/^[A-Z]+:\s*/, '').gsub('|', '\\|')
      winner_techniques << "**#{@results[i][:name]}**: #{technique_name}"
      @summary[@results[i][:name]][:best_technique] += 1
    end

    unique_winners = winners.compact.uniq
    out
    if unique_winners.size == 1
      technique_name = unique_winners.first.sub(/^[A-Z]+:\s*/, '').gsub('|', '\\|')
      out "> **All agree**: #{technique_name}"
    else
      out "> #{winner_techniques.join(' | ')}"
    end
    out
  end

  def compare_operations
    ops_by_result = @results.map do |r|
      ops = r[:data]['operations'] || r[:data]['benchmarks'] || []
      ops.reject { |b| TECHNIQUE_CATEGORIES.keys.any? { |p| b['name'].start_with?(p) } }
    end
    return if ops_by_result.all?(&:empty?)

    out "## Operation Benchmarks"
    out
    out "Format: **time** (gc collections, heap MB)"
    out

    header = "| Benchmark |"
    separator = "|:----------|"
    @results.each do |r|
      header += " #{r[:name]} |"
      separator += "----------:|"
    end
    header += " Winner | Factor |"
    separator += ":------:|-------:|"
    out header
    out separator

    all_names = ops_by_result.flatten.map { |b| b['name'] }.uniq

    all_names.sort.each do |name|
      benches = ops_by_result.map { |ops| ops.find { |b| b['name'] == name } }
      times = benches.map { |b| b ? get_time(b) : nil }

      next if times.compact.empty?

      valid_times = times.each_with_index.select { |t, _| t }.map { |t, i| [t, i] }
      fastest_idx = valid_times.min_by { |t, _| t }[1] if valid_times.any?
      slowest_time = valid_times.max_by { |t, _| t }[0] if valid_times.any?
      fastest_time = valid_times.min_by { |t, _| t }[0] if valid_times.any?

      row = "| #{name} |"

      benches.each_with_index do |bench, i|
        if bench.nil?
          row += " - |"
        else
          time = get_time(bench)
          gc = get_gc_count(bench)
          heap = get_heap_mb(bench)

          # Build info string
          info_parts = []
          info_parts << gc.to_s if gc > 0
          info_parts << "#{heap}MB" if heap > 0
          info_str = info_parts.empty? ? "" : " (#{info_parts.join(', ')})"

          time_str = "%.4f#{info_str}" % time
          if i == fastest_idx
            row += " **#{time_str}** |"
            @summary[@results[i][:name]][:op_wins] += 1
          else
            row += " #{time_str} |"
          end
        end
      end

      winner_name = fastest_idx ? @results[fastest_idx][:name] : "-"
      factor = (fastest_time && slowest_time && fastest_time > 0) ? slowest_time / fastest_time : 1.0
      row += " #{winner_name} | %.1fx |" % factor
      out row
    end
    out
  end

  def write_summary
    out "## Summary"
    out

    out "### Technique Wins"
    out
    out "| Ruby | Wins |"
    out "|:-----|-----:|"
    @results.each do |r|
      out "| #{r[:name]} | #{@summary[r[:name]][:technique_wins]} |"
    end
    out

    out "### Operation Wins"
    out
    out "| Ruby | Wins |"
    out "|:-----|-----:|"
    @results.each do |r|
      out "| #{r[:name]} | #{@summary[r[:name]][:op_wins]} |"
    end
    out

    out "### Overall"
    out
    out "| Ruby | Total Wins |"
    out "|:-----|----------:|"
    totals = @results.map do |r|
      total = @summary[r[:name]][:technique_wins] + @summary[r[:name]][:op_wins]
      [r[:name], total]
    end.sort_by { |_, t| -t }
    totals.each { |name, total| out "| #{name} | #{total} |" }
    out
  end

  def write_recommendations
    techniques_by_result = @results.map { |r| r[:data]['techniques'] || [] }
    return if techniques_by_result.all?(&:empty?)

    out "## Recommendations"
    out
    out "Best technique to use for each category:"
    out

    out "| Category | Recommendation |"
    out "|:---------|:---------------|"

    TECHNIQUE_CATEGORIES.each do |prefix, category_name|
      results_per_ruby = techniques_by_result.map { |t| t.select { |b| b['name'].start_with?(prefix) } }
      next if results_per_ruby.all?(&:empty?)

      winners = results_per_ruby.each_with_index.map do |results, i|
        next nil if results.empty?
        best = results.min_by { |b| get_time(b) }
        technique_name = best['name'].sub(/^[A-Z]+:\s*/, '').gsub('|', '\\|')
        [technique_name, @results[i][:name]]
      end.compact

      unique_techniques = winners.map(&:first).uniq
      if unique_techniques.size == 1
        out "| #{category_name} | `#{unique_techniques.first}` |"
      else
        rec = winners.map { |tech, ruby| "#{ruby}: `#{tech}`" }.join(", ")
        out "| #{category_name} | #{rec} |"
      end
    end
    out
  end

  def get_time(bench)
    bench.dig('time', 'avg') || bench['avg_time'] || 0
  end

  def get_gc_count(bench)
    bench.dig('gc', 'collections') || 0
  end

  def get_heap_mb(bench)
    # Try different heap metrics depending on Ruby engine
    # JRuby uses heap_used_bytes_after, MRI uses rss_mb_after
    if bench.dig('gc', 'heap_used_bytes_after')
      bytes = bench.dig('gc', 'heap_used_bytes_after')
      mb = bytes / 1024.0 / 1024.0
    elsif bench.dig('memory', 'rss_mb_after')
      mb = bench.dig('memory', 'rss_mb_after')
    else
      mb = 0
    end
    mb > 1 ? mb.round(1) : 0
  end
end

if __FILE__ == $0
  if ARGV.size >= 2
    files = ARGV
  else
    mri = Dir['results/bench_mri_*.json'].sort.last
    jruby10 = Dir['results/bench_jruby10_*.json'].sort.last
    jruby17 = Dir['results/bench_jruby1_*.json'].sort.last
    truffleruby = Dir['results/bench_truffleruby_*.json'].sort.last

    files = [mri, jruby10, jruby17, truffleruby].compact

    if files.size < 2
      puts "Usage: ruby compare_techniques.rb <result1.json> <result2.json> [result3.json ...]"
      puts "   or: Run benchmarks for multiple Ruby versions first"
      puts
      puts "Found: #{files.join(', ')}"
      exit 1
    end
  end

  puts "Comparing: #{files.join(', ')}"

  comparator = BenchmarkComparator.new(files)

  # Generate timestamped filename
  timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
  output_file = "results/comparison_#{timestamp}.md"

  comparator.save(output_file)

  # Also print to stdout
  puts
  puts File.read(output_file)
end
