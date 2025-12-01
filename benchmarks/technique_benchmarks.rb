# encoding: utf-8
# frozen_string_literal: true

require_relative '../lib/benchmark_runner'
require 'stringio'

module TechniqueBenchmarks
  extend self

  def run_all(options = {})
    iterations = options[:iterations] || 5
    results = []

    puts "\n#{'=' * 70}"
    puts "TECHNIQUE COMPARISONS - #{BenchmarkRunner.ruby_version_info}"
    puts "#{'=' * 70}"

    results.concat(string_building_techniques(iterations))
    results.concat(array_iteration_techniques(iterations))
    results.concat(array_building_techniques(iterations))
    results.concat(array_sorting_techniques(iterations))
    results.concat(hash_building_techniques(iterations))
    results.concat(hash_access_techniques(iterations))
    results.concat(conditional_techniques(iterations))
    results.concat(loop_techniques(iterations))
    results.concat(string_search_techniques(iterations))
    results.concat(collection_filtering_techniques(iterations))
    results.concat(collection_transform_techniques(iterations))
    results.concat(number_conversion_techniques(iterations))
    results.concat(nil_handling_techniques(iterations))
    results.concat(object_duplication_techniques(iterations))

    results
  end

  private

  # === STRING BUILDING ===
  def string_building_techniques(iterations)
    puts "\n--- String Building (10k concatenations) ---"
    words = Array.new(10_000) { |i| "word#{i}" }

    [
      BenchmarkRunner.run(:name => "STR: + operator", :iterations => iterations) {
        result = ""
        words.each { |w| result = result + w }
        result
      },
      BenchmarkRunner.run(:name => "STR: << shovel", :iterations => iterations) {
        result = "".dup
        words.each { |w| result << w }
        result
      },
      BenchmarkRunner.run(:name => "STR: concat", :iterations => iterations) {
        result = "".dup
        words.each { |w| result.concat(w) }
        result
      },
      BenchmarkRunner.run(:name => "STR: Array#join", :iterations => iterations) {
        words.join
      },
      BenchmarkRunner.run(:name => "STR: StringIO", :iterations => iterations) {
        sio = StringIO.new
        words.each { |w| sio << w }
        sio.string
      },
      BenchmarkRunner.run(:name => "STR: each_with_object", :iterations => iterations) {
        words.each_with_object("".dup) { |w, s| s << w }
      },
      BenchmarkRunner.run(:name => "STR: inject <<", :iterations => iterations) {
        words.inject("".dup) { |s, w| s << w }
      },
      BenchmarkRunner.run(:name => "STR: interpolation", :iterations => iterations) {
        result = "".dup
        words.each { |w| result = "#{result}#{w}" }
        result
      }
    ]
  end

  # === ARRAY ITERATION (sum) ===
  def array_iteration_techniques(iterations)
    puts "\n--- Array Iteration: Sum 1M integers ---"
    data = (1..1_000_000).to_a

    results = []

    # Array#sum requires Ruby 2.4+
    if HAS_ARRAY_SUM
      results << BenchmarkRunner.run(:name => "ITER: sum", :iterations => iterations) {
        data.sum
      }
    else
      puts "  [skipped] ITER: sum (requires Ruby 2.4+)"
    end

    results << BenchmarkRunner.run(:name => "ITER: reduce(:+)", :iterations => iterations) {
      data.reduce(:+)
    }
    results << BenchmarkRunner.run(:name => "ITER: reduce block", :iterations => iterations) {
      data.reduce(0) { |sum, n| sum + n }
    }
    results << BenchmarkRunner.run(:name => "ITER: each + var", :iterations => iterations) {
      sum = 0
      data.each { |n| sum += n }
      sum
    }
    results << BenchmarkRunner.run(:name => "ITER: while index", :iterations => iterations) {
      sum = 0
      i = 0
      len = data.length
      while i < len
        sum += data[i]
        i += 1
      end
      sum
    }
    results << BenchmarkRunner.run(:name => "ITER: for in", :iterations => iterations) {
      sum = 0
      for n in data
        sum += n
      end
      sum
    }

    results
  end

  # === ARRAY BUILDING ===
  def array_building_techniques(iterations)
    puts "\n--- Array Building: 100k elements ---"

    [
      BenchmarkRunner.run(:name => "ARR: Range#to_a", :iterations => iterations) {
        (0...100_000).to_a
      },
      BenchmarkRunner.run(:name => "ARR: Array.new block", :iterations => iterations) {
        Array.new(100_000) { |i| i }
      },
      BenchmarkRunner.run(:name => "ARR: Range#map", :iterations => iterations) {
        (0...100_000).map { |i| i }
      },
      BenchmarkRunner.run(:name => "ARR: << in times", :iterations => iterations) {
        arr = []
        100_000.times { |i| arr << i }
        arr
      },
      BenchmarkRunner.run(:name => "ARR: push in times", :iterations => iterations) {
        arr = []
        100_000.times { |i| arr.push(i) }
        arr
      },
      BenchmarkRunner.run(:name => "ARR: each_with_object", :iterations => iterations) {
        (0...100_000).each_with_object([]) { |i, arr| arr << i }
      }
    ]
  end

  # === ARRAY SORTING ===
  def array_sorting_techniques(iterations)
    puts "\n--- Array Sorting: 50k random integers ---"

    results = [
      BenchmarkRunner.run(:name => "SORT: sort", :iterations => iterations) {
        arr = Array.new(50_000) { rand(100_000) }
        arr.sort
      },
      BenchmarkRunner.run(:name => "SORT: sort!", :iterations => iterations) {
        arr = Array.new(50_000) { rand(100_000) }
        arr.sort!
      },
      BenchmarkRunner.run(:name => "SORT: sort block", :iterations => iterations) {
        arr = Array.new(50_000) { rand(100_000) }
        arr.sort { |a, b| a <=> b }
      },
      BenchmarkRunner.run(:name => "SORT: sort_by", :iterations => iterations) {
        arr = Array.new(50_000) { rand(100_000) }
        arr.sort_by { |x| x }
      }
    ]

    # Object#itself requires Ruby 2.2+
    if HAS_ITSELF
      results << BenchmarkRunner.run(:name => "SORT: sort_by(&:itself)", :iterations => iterations) {
        arr = Array.new(50_000) { rand(100_000) }
        arr.sort_by(&:itself)
      }
    else
      puts "  [skipped] SORT: sort_by(&:itself) (requires Ruby 2.2+)"
    end

    results
  end

  # === HASH BUILDING ===
  def hash_building_techniques(iterations)
    puts "\n--- Hash Building: 50k key-value pairs ---"
    keys = Array.new(50_000) { |i| "key#{i}" }
    values = (0...50_000).to_a

    results = [
      BenchmarkRunner.run(:name => "HASH: []= loop", :iterations => iterations) {
        h = {}
        keys.each_with_index { |k, i| h[k] = i }
        h
      }
    ]

    # Array#to_h requires Ruby 2.1+
    if HAS_ARRAY_TO_H
      results << BenchmarkRunner.run(:name => "HASH: zip.to_h", :iterations => iterations) {
        keys.zip(values).to_h
      }
    else
      puts "  [skipped] HASH: zip.to_h (requires Ruby 2.1+)"
    end

    results << BenchmarkRunner.run(:name => "HASH: each_with_object", :iterations => iterations) {
      keys.each_with_index.each_with_object({}) { |(k, i), h| h[k] = i }
    }

    if HAS_ARRAY_TO_H
      results << BenchmarkRunner.run(:name => "HASH: map.to_h", :iterations => iterations) {
        keys.each_with_index.map { |k, i| [k, i] }.to_h
      }
    else
      puts "  [skipped] HASH: map.to_h (requires Ruby 2.1+)"
    end

    results << BenchmarkRunner.run(:name => "HASH: Hash[]", :iterations => iterations) {
      Hash[keys.zip(values)]
    }

    results
  end

  # === HASH ACCESS ===
  def hash_access_techniques(iterations)
    puts "\n--- Hash Access: 500k lookups ---"
    hash = Hash[(0...1000).map { |i| ["key#{i}", i] }]
    lookups = Array.new(500_000) { "key#{rand(1000)}" }
    missing = Array.new(500_000) { "missing#{rand(1000)}" }

    results = [
      BenchmarkRunner.run(:name => "ACCESS: [] existing", :iterations => iterations) {
        lookups.map { |k| hash[k] }
      },
      BenchmarkRunner.run(:name => "ACCESS: fetch existing", :iterations => iterations) {
        lookups.map { |k| hash.fetch(k) }
      },
      BenchmarkRunner.run(:name => "ACCESS: [] missing", :iterations => iterations) {
        missing.map { |k| hash[k] }
      },
      BenchmarkRunner.run(:name => "ACCESS: fetch default", :iterations => iterations) {
        missing.map { |k| hash.fetch(k, 0) }
      },
      BenchmarkRunner.run(:name => "ACCESS: || default", :iterations => iterations) {
        missing.map { |k| hash[k] || 0 }
      }
    ]

    # Hash#dig requires Ruby 2.3+
    if HAS_HASH_DIG
      results << BenchmarkRunner.run(:name => "ACCESS: dig", :iterations => iterations) {
        lookups.map { |k| hash.dig(k) }
      }
    else
      puts "  [skipped] ACCESS: dig (requires Ruby 2.3+)"
    end

    results
  end

  # === CONDITIONALS ===
  def conditional_techniques(iterations)
    puts "\n--- Conditionals: 1M value classifications ---"
    values = Array.new(1_000_000) { rand(10) }
    lookup = { 0 => :low, 1 => :low, 2 => :low, 3 => :mid, 4 => :mid, 5 => :mid, 6 => :mid }
    lookup.default = :high

    [
      BenchmarkRunner.run(:name => "COND: ternary", :iterations => iterations) {
        values.map { |v| v < 3 ? :low : (v < 7 ? :mid : :high) }
      },
      BenchmarkRunner.run(:name => "COND: if/elsif", :iterations => iterations) {
        values.map do |v|
          if v < 3 then :low
          elsif v < 7 then :mid
          else :high
          end
        end
      },
      BenchmarkRunner.run(:name => "COND: case/when", :iterations => iterations) {
        values.map do |v|
          case v
          when 0..2 then :low
          when 3..6 then :mid
          else :high
          end
        end
      },
      BenchmarkRunner.run(:name => "COND: hash lookup", :iterations => iterations) {
        values.map { |v| lookup[v] }
      },
      BenchmarkRunner.run(:name => "COND: array lookup", :iterations => iterations) {
        arr = [:low, :low, :low, :mid, :mid, :mid, :mid, :high, :high, :high]
        values.map { |v| arr[v] }
      }
    ]
  end

  # === LOOP TECHNIQUES ===
  def loop_techniques(iterations)
    puts "\n--- Loops: 1M iterations ---"

    [
      BenchmarkRunner.run(:name => "LOOP: while", :iterations => iterations) {
        sum = 0
        i = 0
        while i < 1_000_000
          sum += i
          i += 1
        end
        sum
      },
      BenchmarkRunner.run(:name => "LOOP: times", :iterations => iterations) {
        sum = 0
        1_000_000.times { |i| sum += i }
        sum
      },
      BenchmarkRunner.run(:name => "LOOP: upto", :iterations => iterations) {
        sum = 0
        0.upto(999_999) { |i| sum += i }
        sum
      },
      BenchmarkRunner.run(:name => "LOOP: range.each", :iterations => iterations) {
        sum = 0
        (0...1_000_000).each { |i| sum += i }
        sum
      },
      BenchmarkRunner.run(:name => "LOOP: step", :iterations => iterations) {
        sum = 0
        0.step(999_999, 1) { |i| sum += i }
        sum
      },
      BenchmarkRunner.run(:name => "LOOP: loop+break", :iterations => iterations) {
        sum = 0
        i = 0
        loop do
          break if i >= 1_000_000
          sum += i
          i += 1
        end
        sum
      }
    ]
  end

  # === STRING SEARCHING ===
  def string_search_techniques(iterations)
    puts "\n--- String Search: 100k substring searches ---"
    text = "The quick brown fox jumps over the lazy dog. " * 100
    needles = Array.new(100_000) { %w[fox dog cat bird].sample }

    results = [
      BenchmarkRunner.run(:name => "SEARCH: include?", :iterations => iterations) {
        needles.count { |s| text.include?(s) }
      },
      BenchmarkRunner.run(:name => "SEARCH: index", :iterations => iterations) {
        needles.count { |s| text.index(s) }
      },
      BenchmarkRunner.run(:name => "SEARCH: []", :iterations => iterations) {
        needles.count { |s| text[s] }
      }
    ]

    # String#match? requires Ruby 2.4+
    if HAS_STRING_MATCH_Q
      results << BenchmarkRunner.run(:name => "SEARCH: match?", :iterations => iterations) {
        needles.count { |s| text.match?(s) }
      }
    else
      puts "  [skipped] SEARCH: match? (requires Ruby 2.4+)"
    end

    results << BenchmarkRunner.run(:name => "SEARCH: =~ regex", :iterations => iterations) {
      needles.count { |s| text =~ /#{s}/ }
    }
    results << BenchmarkRunner.run(:name => "SEARCH: start_with?", :iterations => iterations) {
      needles.count { |s| text.start_with?(s) }
    }

    results
  end

  # === COLLECTION FILTERING ===
  def collection_filtering_techniques(iterations)
    puts "\n--- Filtering: select evens from 500k ---"
    data = (1..500_000).to_a

    results = [
      BenchmarkRunner.run(:name => "FILTER: select", :iterations => iterations) {
        data.select { |n| n.even? }
      },
      BenchmarkRunner.run(:name => "FILTER: select &:even?", :iterations => iterations) {
        data.select(&:even?)
      },
      BenchmarkRunner.run(:name => "FILTER: reject", :iterations => iterations) {
        data.reject { |n| n.odd? }
      },
      BenchmarkRunner.run(:name => "FILTER: each + <<", :iterations => iterations) {
        result = []
        data.each { |n| result << n if n.even? }
        result
      },
      BenchmarkRunner.run(:name => "FILTER: partition[0]", :iterations => iterations) {
        data.partition { |n| n.even? }[0]
      }
    ]

    # Enumerable#filter_map requires Ruby 2.7+
    if HAS_FILTER_MAP
      results << BenchmarkRunner.run(:name => "FILTER: filter_map", :iterations => iterations) {
        data.filter_map { |n| n if n.even? }
      }
    else
      puts "  [skipped] FILTER: filter_map (requires Ruby 2.7+)"
    end

    results
  end

  # === COLLECTION TRANSFORM ===
  def collection_transform_techniques(iterations)
    puts "\n--- Transform: double 500k integers ---"
    data = (1..500_000).to_a

    [
      BenchmarkRunner.run(:name => "XFORM: map", :iterations => iterations) {
        data.map { |n| n * 2 }
      },
      BenchmarkRunner.run(:name => "XFORM: map &proc", :iterations => iterations) {
        double = lambda { |n| n * 2 }
        data.map(&double)
      },
      BenchmarkRunner.run(:name => "XFORM: collect", :iterations => iterations) {
        data.collect { |n| n * 2 }
      },
      BenchmarkRunner.run(:name => "XFORM: each_with_object", :iterations => iterations) {
        data.each_with_object([]) { |n, arr| arr << n * 2 }
      },
      BenchmarkRunner.run(:name => "XFORM: inject", :iterations => iterations) {
        data.inject([]) { |arr, n| arr << n * 2 }
      }
    ]
  end

  # === NUMBER CONVERSION ===
  def number_conversion_techniques(iterations)
    puts "\n--- Number Conversion: 100k strings to int ---"
    strings = Array.new(100_000) { rand(1_000_000).to_s }

    [
      BenchmarkRunner.run(:name => "CONV: map(&:to_i)", :iterations => iterations) {
        strings.map(&:to_i)
      },
      BenchmarkRunner.run(:name => "CONV: map { to_i }", :iterations => iterations) {
        strings.map { |s| s.to_i }
      },
      BenchmarkRunner.run(:name => "CONV: Integer()", :iterations => iterations) {
        strings.map { |s| Integer(s) }
      },
      BenchmarkRunner.run(:name => "CONV: Integer(s,10)", :iterations => iterations) {
        strings.map { |s| Integer(s, 10) }
      }
    ]
  end

  # === NIL HANDLING ===
  def nil_handling_techniques(iterations)
    puts "\n--- Nil Handling: 500k values (20% nil) ---"
    data = Array.new(500_000) { rand < 0.2 ? nil : rand(100) }

    results = [
      BenchmarkRunner.run(:name => "NIL: || default", :iterations => iterations) {
        data.map { |v| v || 0 }
      },
      BenchmarkRunner.run(:name => "NIL: v.nil? ternary", :iterations => iterations) {
        data.map { |v| v.nil? ? 0 : v }
      },
      BenchmarkRunner.run(:name => "NIL: to_i", :iterations => iterations) {
        data.map { |v| v.to_i }
      }
    ]

    # Array#sum requires Ruby 2.4+
    if HAS_ARRAY_SUM
      results << BenchmarkRunner.run(:name => "NIL: compact.sum", :iterations => iterations) {
        data.compact.sum
      }
    else
      puts "  [skipped] NIL: compact.sum (requires Ruby 2.4+)"
    end

    # Object#itself requires Ruby 2.2+
    if HAS_ITSELF
      results << BenchmarkRunner.run(:name => "NIL: nil? ? 0 : itself", :iterations => iterations) {
        data.map { |v| v.nil? ? 0 : v.itself }
      }
    else
      puts "  [skipped] NIL: nil? ? 0 : itself (requires Ruby 2.2+)"
    end

    results
  end

  # === OBJECT DUPLICATION ===
  def object_duplication_techniques(iterations)
    puts "\n--- Object Duplication: 100k copies ---"
    template = { :name => "test", :values => [1, 2, 3], :nested => { :a => 1, :b => 2 } }

    [
      BenchmarkRunner.run(:name => "DUP: dup", :iterations => iterations) {
        result = []
        100_000.times { result << template.dup }
        result
      },
      BenchmarkRunner.run(:name => "DUP: clone", :iterations => iterations) {
        result = []
        100_000.times { result << template.clone }
        result
      },
      BenchmarkRunner.run(:name => "DUP: Hash[]", :iterations => iterations) {
        result = []
        100_000.times { result << Hash[template] }
        result
      },
      BenchmarkRunner.run(:name => "DUP: merge({})", :iterations => iterations) {
        result = []
        100_000.times { result << template.merge({}) }
        result
      },
      BenchmarkRunner.run(:name => "DUP: to_h", :iterations => iterations) {
        result = []
        100_000.times { result << template.to_h }
        result
      }
    ]
  end
end
