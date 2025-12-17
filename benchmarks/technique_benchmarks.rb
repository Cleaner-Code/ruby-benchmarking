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
    results.concat(hash_key_iteration_techniques(iterations))
    results.concat(conditional_techniques(iterations))
    results.concat(loop_techniques(iterations))
    results.concat(string_search_techniques(iterations))
    results.concat(collection_filtering_techniques(iterations))
    results.concat(collection_transform_techniques(iterations))
    results.concat(number_conversion_techniques(iterations))
    results.concat(nil_handling_techniques(iterations))
    results.concat(object_duplication_techniques(iterations))
    results.concat(method_invocation_techniques(iterations))
    results.concat(block_yield_techniques(iterations))
    results.concat(eval_techniques(iterations))
    results.concat(caller_techniques(iterations))
    results.concat(marshal_techniques(iterations))
    results.concat(memoization_techniques(iterations))
    results.concat(set_vs_array_techniques(iterations))
    results.concat(mutex_techniques(iterations))
    results.concat(thread_local_techniques(iterations))
    results.concat(data_structure_techniques(iterations))
    results.concat(yaml_techniques(iterations))
    results.concat(lazy_techniques(iterations))
    results.concat(grouping_techniques(iterations))
    results.concat(metaprogramming_techniques(iterations))
    results.concat(exception_techniques(iterations))
    results.concat(string_freeze_techniques(iterations))
    results.concat(split_techniques(iterations))

    results
  end

  private

  # === STRING BUILDING ===
  def string_building_techniques(iterations)
    puts "\n--- String Building (2k concatenations) ---"
    words = Array.new(2_000) { |i| "word#{i}" }

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

  # === HASH KEY ITERATION ===
  def hash_key_iteration_techniques(iterations)
    puts "\n--- Hash Key Iteration: 20k entries x 1000 ---"
    # Simulates real-world use case with frozen string keys
    hash = {}
    20_000.times { |i| hash["key#{i}".freeze] = i }

    [
      BenchmarkRunner.run(:name => "HKEY: keys.map", :iterations => iterations) {
        1000.times { hash.keys.map { |k| k.upcase } }
      },
      BenchmarkRunner.run(:name => "HKEY: map { |k,_| }", :iterations => iterations) {
        1000.times { hash.map { |k,_| k.upcase } }
      },
      BenchmarkRunner.run(:name => "HKEY: each_key.map", :iterations => iterations) {
        1000.times { hash.each_key.map { |k| k.upcase } }
      },
      BenchmarkRunner.run(:name => "HKEY: keys.each", :iterations => iterations) {
        1000.times { result = []; hash.keys.each { |k| result << k.upcase }; result }
      },
      BenchmarkRunner.run(:name => "HKEY: each { |k,_| }", :iterations => iterations) {
        1000.times { result = []; hash.each { |k,_| result << k.upcase }; result }
      }
    ]
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

  # === METHOD INVOCATION ===
  def method_invocation_techniques(iterations)
    puts "\n--- Method Invocation: 500k calls ---"

    # Simple test object
    obj = Object.new
    def obj.test_method
      42
    end

    method_name = :test_method
    bound_method = obj.method(:test_method)

    [
      BenchmarkRunner.run(:name => "CALL: direct", :iterations => iterations) {
        result = 0
        500_000.times { result = obj.test_method }
        result
      },
      BenchmarkRunner.run(:name => "CALL: send", :iterations => iterations) {
        result = 0
        500_000.times { result = obj.send(method_name) }
        result
      },
      BenchmarkRunner.run(:name => "CALL: public_send", :iterations => iterations) {
        result = 0
        500_000.times { result = obj.public_send(method_name) }
        result
      },
      BenchmarkRunner.run(:name => "CALL: method.call", :iterations => iterations) {
        result = 0
        500_000.times { result = bound_method.call }
        result
      },
      BenchmarkRunner.run(:name => "CALL: __send__", :iterations => iterations) {
        result = 0
        500_000.times { result = obj.__send__(method_name) }
        result
      }
    ]
  end

  # === BLOCK/YIELD PERFORMANCE ===
  # NOTE: All benchmarks accumulate results to prevent JIT dead code elimination
  def block_yield_techniques(iterations)
    puts "\n--- Block/Yield: 2M iterations ---"

    # Helper methods for yield testing - accumulate results to prevent JIT optimization
    def self.with_yield(n)
      sum = 0
      n.times { sum += yield }
      sum
    end

    def self.with_block(n, &block)
      sum = 0
      n.times { sum += block.call }
      sum
    end

    def self.nested_yield(n)
      with_yield(n) { yield }
    end

    # Block is accepted but never called - tests closure creation overhead
    def self.noop_block(&block)
      0
    end

    # Block is accepted via yield syntax but never yielded - tests closure creation overhead
    def self.noop_yield
      0
    end

    my_proc = Proc.new { 1 + 1 }
    my_lambda = lambda { 1 + 1 }
    n = 2_000_000  # 2M iterations for stable measurements
    arr = Array.new(500_000) { rand(100) }
    result = nil  # Prevent JIT from optimizing away results

    [
      BenchmarkRunner.run(:name => "BLOCK: yield", :iterations => iterations) {
        result = with_yield(n) { 1 + 1 }
      },
      BenchmarkRunner.run(:name => "BLOCK: block.call", :iterations => iterations) {
        result = with_block(n) { 1 + 1 }
      },
      BenchmarkRunner.run(:name => "BLOCK: nested yield", :iterations => iterations) {
        result = nested_yield(n) { 1 + 1 }
      },
      BenchmarkRunner.run(:name => "BLOCK: proc.call", :iterations => iterations) {
        sum = 0
        n.times { sum += my_proc.call }
        result = sum
      },
      BenchmarkRunner.run(:name => "BLOCK: lambda.call", :iterations => iterations) {
        sum = 0
        n.times { sum += my_lambda.call }
        result = sum
      },
      BenchmarkRunner.run(:name => "BLOCK: each { }", :iterations => iterations) {
        sum = 0
        arr.each { |x| sum += x + 1 }
        result = sum
      },
      BenchmarkRunner.run(:name => "BLOCK: map { }", :iterations => iterations) {
        result = arr.map { |x| x + 1 }
      },
      BenchmarkRunner.run(:name => "BLOCK: select { }", :iterations => iterations) {
        result = arr.select { |x| x > 50 }
      },
      # Closure creation overhead - block passed but never called
      BenchmarkRunner.run(:name => "BLOCK: unused closure (&block)", :iterations => iterations) {
        sum = 0
        n.times do
          x = 4711
          sum += noop_block { x * x }
        end
        result = sum
      },
      BenchmarkRunner.run(:name => "BLOCK: unused closure (yield)", :iterations => iterations) {
        sum = 0
        n.times do
          x = 4711
          sum += noop_yield { x * x }
        end
        result = sum
      },
      # Baseline: no block at all
      BenchmarkRunner.run(:name => "BLOCK: no block baseline", :iterations => iterations) {
        sum = 0
        n.times do
          x = 4711
          sum += 0
        end
        result = sum
      }
    ]
  end

  # === EVAL PERFORMANCE ===
  # NOTE: All benchmarks accumulate and return results to prevent JIT dead code elimination
  def eval_techniques(iterations)
    puts "\n--- Eval: 50k iterations ---"

    n = 50_000
    obj = Object.new
    klass = Class.new
    b = binding

    [
      BenchmarkRunner.run(:name => "EVAL: eval simple", :iterations => iterations) {
        sum = 0
        n.times { sum += eval("1 + 1") }
        sum
      },
      BenchmarkRunner.run(:name => "EVAL: eval vars", :iterations => iterations) {
        sum = 0
        n.times { sum += eval("x = 5; x * 2") }
        sum
      },
      BenchmarkRunner.run(:name => "EVAL: instance_eval str", :iterations => iterations) {
        sum = 0
        n.times { sum += obj.instance_eval("1 + 1") }
        sum
      },
      BenchmarkRunner.run(:name => "EVAL: instance_eval blk", :iterations => iterations) {
        sum = 0
        n.times { sum += obj.instance_eval { 1 + 1 } }
        sum
      },
      BenchmarkRunner.run(:name => "EVAL: class_eval str", :iterations => iterations) {
        sum = 0
        n.times { sum += klass.class_eval("1 + 1") }
        sum
      },
      BenchmarkRunner.run(:name => "EVAL: class_eval blk", :iterations => iterations) {
        sum = 0
        n.times { sum += klass.class_eval { 1 + 1 } }
        sum
      },
      BenchmarkRunner.run(:name => "EVAL: binding.eval", :iterations => iterations) {
        sum = 0
        n.times { sum += b.eval("1 + 1") }
        sum
      },
      BenchmarkRunner.run(:name => "EVAL: direct (baseline)", :iterations => iterations) {
        sum = 0
        n.times { sum += 1 + 1 }
        sum
      }
    ]
  end

  # === CALLER PERFORMANCE ===
  # NOTE: All benchmarks accumulate and return results to prevent JIT dead code elimination
  def caller_techniques(iterations)
    puts "\n--- Caller: 100k iterations ---"

    n = 100_000

    results = [
      BenchmarkRunner.run(:name => "CALLER: caller()", :iterations => iterations) {
        count = 0
        n.times { count += caller.length }
        count
      },
      BenchmarkRunner.run(:name => "CALLER: caller(0)", :iterations => iterations) {
        count = 0
        n.times { count += caller(0).length }
        count
      }
    ]

    # caller(start, length) - Ruby 2.0+
    if RUBY_VERSION >= '2.0'
      results << BenchmarkRunner.run(:name => "CALLER: caller(0, 1)", :iterations => iterations) {
        count = 0
        n.times { count += caller(0, 1).length }
        count
      }
      results << BenchmarkRunner.run(:name => "CALLER: caller(0, 5)", :iterations => iterations) {
        count = 0
        n.times { count += caller(0, 5).length }
        count
      }
    else
      puts "  [skipped] CALLER: caller(0, 1) (requires Ruby 2.0+)"
      puts "  [skipped] CALLER: caller(0, 5) (requires Ruby 2.0+)"
    end

    # caller_locations - Ruby 2.0+
    if Kernel.respond_to?(:caller_locations)
      results << BenchmarkRunner.run(:name => "CALLER: caller_locations(0, 1)", :iterations => iterations) {
        count = 0
        n.times { count += caller_locations(0, 1).length }
        count
      }
      results << BenchmarkRunner.run(:name => "CALLER: caller_locations(0, 5)", :iterations => iterations) {
        count = 0
        n.times { count += caller_locations(0, 5).length }
        count
      }
    else
      puts "  [skipped] CALLER: caller_locations (requires Ruby 2.0+)"
    end

    results
  end

  # === MARSHAL SERIALIZATION ===
  def marshal_techniques(iterations)
    puts "\n--- Marshal: serialization patterns ---"

    small_data = { :id => 1, :name => "test", :values => [1, 2, 3] }
    medium_data = {
      :id => 1,
      :name => "test" * 100,
      :values => (1..1000).to_a,
      :nested => { :a => 1, :b => 2, :c => (1..100).to_a }
    }

    [
      BenchmarkRunner.run(:name => "MARSHAL: dump/load small 1k", :iterations => iterations) {
        1000.times { Marshal.load(Marshal.dump(small_data)) }
      },
      BenchmarkRunner.run(:name => "MARSHAL: dump/load medium 1k", :iterations => iterations) {
        1000.times { Marshal.load(Marshal.dump(medium_data)) }
      },
      BenchmarkRunner.run(:name => "MARSHAL: dump only medium 1k", :iterations => iterations) {
        1000.times { Marshal.dump(medium_data) }
      },
      BenchmarkRunner.run(:name => "MARSHAL: load only medium 1k", :iterations => iterations) {
        dumped = Marshal.dump(medium_data)
        1000.times { Marshal.load(dumped) }
      }
    ]
  end

  # === MEMOIZATION PATTERNS ===
  def memoization_techniques(iterations)
    puts "\n--- Memoization: caching patterns ---"

    [
      BenchmarkRunner.run(:name => "MEMO: ||= hash key 100k", :iterations => iterations) {
        cache = {}
        100_000.times { |i|
          key = i % 100
          cache[key] ||= "computed_#{key}"
        }
      },
      BenchmarkRunner.run(:name => "MEMO: fetch block 100k", :iterations => iterations) {
        cache = {}
        100_000.times { |i|
          key = i % 100
          cache.fetch(key) { cache[key] = "computed_#{key}" }
        }
      },
      BenchmarkRunner.run(:name => "MEMO: key? + []= 100k", :iterations => iterations) {
        cache = {}
        100_000.times { |i|
          key = i % 100
          cache[key] = "computed_#{key}" unless cache.key?(key)
          cache[key]
        }
      },
      BenchmarkRunner.run(:name => "MEMO: ivar ||= 100k", :iterations => iterations) {
        obj = Object.new
        100_000.times {
          val = obj.instance_variable_get(:@cached)
          unless val
            val = "computed"
            obj.instance_variable_set(:@cached, val)
          end
          val
        }
      }
    ]
  end

  # === SET VS ARRAY LOOKUP ===
  # NOTE: All benchmarks accumulate and return results to prevent JIT dead code elimination
  def set_vs_array_techniques(iterations)
    puts "\n--- Set vs Array: lookup patterns ---"

    require 'set'

    arr_10 = (1..10).to_a
    arr_100 = (1..100).to_a
    arr_1000 = (1..1000).to_a

    results = [
      BenchmarkRunner.run(:name => "SETARR: Array#include? 10 100k", :iterations => iterations) {
        count = 0
        100_000.times { count += 1 if arr_10.include?(5) }
        count
      },
      BenchmarkRunner.run(:name => "SETARR: Set.new+incl 10 100k", :iterations => iterations) {
        count = 0
        100_000.times { count += 1 if Set.new(arr_10).include?(5) }
        count
      },
      BenchmarkRunner.run(:name => "SETARR: Set reuse 10 100k", :iterations => iterations) {
        s = Set.new(arr_10)
        count = 0
        100_000.times { count += 1 if s.include?(5) }
        count
      },
      BenchmarkRunner.run(:name => "SETARR: Array#include? 1k 10k", :iterations => iterations) {
        count = 0
        10_000.times { count += 1 if arr_1000.include?(500) }
        count
      },
      BenchmarkRunner.run(:name => "SETARR: Set.new+incl 1k 10k", :iterations => iterations) {
        count = 0
        10_000.times { count += 1 if Set.new(arr_1000).include?(500) }
        count
      },
      BenchmarkRunner.run(:name => "SETARR: Set reuse 1k 10k", :iterations => iterations) {
        s = Set.new(arr_1000)
        count = 0
        10_000.times { count += 1 if s.include?(500) }
        count
      }
    ]

    results
  end

  # === MUTEX SYNCHRONIZATION ===
  # NOTE: All benchmarks accumulate and return results to prevent JIT dead code elimination
  def mutex_techniques(iterations)
    puts "\n--- Mutex: synchronization overhead ---"

    mutex = Mutex.new

    [
      BenchmarkRunner.run(:name => "MUTEX: no sync 100k", :iterations => iterations) {
        v = 0
        100_000.times { v += 1 }
        v
      },
      BenchmarkRunner.run(:name => "MUTEX: synchronize 100k", :iterations => iterations) {
        v = 0
        100_000.times { mutex.synchronize { v += 1 } }
        v
      },
      BenchmarkRunner.run(:name => "MUTEX: lock/unlock 100k", :iterations => iterations) {
        v = 0
        100_000.times {
          mutex.lock
          v += 1
          mutex.unlock
        }
        v
      },
      BenchmarkRunner.run(:name => "MUTEX: try_lock 100k", :iterations => iterations) {
        v = 0
        100_000.times {
          if mutex.try_lock
            v += 1
            mutex.unlock
          end
        }
        v
      }
    ]
  end

  # === THREAD-LOCAL STORAGE ===
  # NOTE: All benchmarks accumulate and return results to prevent JIT dead code elimination
  def thread_local_techniques(iterations)
    puts "\n--- Thread-local: storage patterns ---"

    Thread.current[:bench_key] = 1

    [
      BenchmarkRunner.run(:name => "THREAD: current[] read 100k", :iterations => iterations) {
        sum = 0
        100_000.times { sum += Thread.current[:bench_key] }
        sum
      },
      BenchmarkRunner.run(:name => "THREAD: current[] write 100k", :iterations => iterations) {
        100_000.times { |i| Thread.current[:bench_key] = i }
        Thread.current[:bench_key]
      },
      BenchmarkRunner.run(:name => "THREAD: ivar read 100k", :iterations => iterations) {
        obj = Object.new
        obj.instance_variable_set(:@val, 1)
        sum = 0
        100_000.times { sum += obj.instance_variable_get(:@val) }
        sum
      },
      BenchmarkRunner.run(:name => "THREAD: local var 100k", :iterations => iterations) {
        local = 1
        sum = 0
        100_000.times { sum += local }
        sum
      }
    ]
  end

  # === DATA STRUCTURES: Struct vs Class vs Hash ===
  # NOTE: All benchmarks accumulate and return results to prevent JIT dead code elimination
  def data_structure_techniques(iterations)
    puts "\n--- Data Structures: Struct vs Class vs Hash ---"

    # Define test class
    klass = Class.new do
      attr_accessor :id, :name, :value
      def initialize(id, name, value)
        @id = id
        @name = name
        @value = value
      end
    end

    # Define test struct
    test_struct = Struct.new(:id, :name, :value)

    [
      BenchmarkRunner.run(:name => "STRUCT: Hash create 10k", :iterations => iterations) {
        result = nil
        10_000.times { |i| result = { :id => i, :name => "item#{i}", :value => i * 10 } }
        result
      },
      BenchmarkRunner.run(:name => "STRUCT: Struct create 10k", :iterations => iterations) {
        result = nil
        10_000.times { |i| result = test_struct.new(i, "item#{i}", i * 10) }
        result
      },
      BenchmarkRunner.run(:name => "STRUCT: Class create 10k", :iterations => iterations) {
        result = nil
        10_000.times { |i| result = klass.new(i, "item#{i}", i * 10) }
        result
      },
      BenchmarkRunner.run(:name => "STRUCT: Hash read 100k", :iterations => iterations) {
        h = { :id => 1, :name => "test", :value => 100 }
        count = 0
        100_000.times { count += h[:name].length }
        count
      },
      BenchmarkRunner.run(:name => "STRUCT: Struct read 100k", :iterations => iterations) {
        s = test_struct.new(1, "test", 100)
        count = 0
        100_000.times { count += s.name.length }
        count
      },
      BenchmarkRunner.run(:name => "STRUCT: Class read 100k", :iterations => iterations) {
        obj = klass.new(1, "test", 100)
        count = 0
        100_000.times { count += obj.name.length }
        count
      },
      BenchmarkRunner.run(:name => "STRUCT: Hash write 100k", :iterations => iterations) {
        h = { :id => 1, :name => "test", :value => 100 }
        100_000.times { |i| h[:name] = "test#{i}" }
        h[:name]
      },
      BenchmarkRunner.run(:name => "STRUCT: Struct write 100k", :iterations => iterations) {
        s = test_struct.new(1, "test", 100)
        100_000.times { |i| s.name = "test#{i}" }
        s.name
      },
      BenchmarkRunner.run(:name => "STRUCT: Class write 100k", :iterations => iterations) {
        obj = klass.new(1, "test", 100)
        100_000.times { |i| obj.name = "test#{i}" }
        obj.name
      }
    ]
  end

  # === YAML SERIALIZATION ===
  def yaml_techniques(iterations)
    puts "\n--- YAML: serialization patterns ---"

    require 'yaml'

    small_data = { :id => 1, :name => "test", :values => [1, 2, 3] }
    medium_data = {
      :id => 1,
      :name => "test" * 50,
      :values => (1..500).to_a,
      :nested => { :a => 1, :b => 2, :c => (1..50).to_a }
    }

    [
      BenchmarkRunner.run(:name => "YAML: dump/load small 1k", :iterations => iterations) {
        1000.times { YAML.load(YAML.dump(small_data)) }
      },
      BenchmarkRunner.run(:name => "YAML: dump/load medium 500", :iterations => iterations) {
        500.times { YAML.load(YAML.dump(medium_data)) }
      },
      BenchmarkRunner.run(:name => "YAML: dump only medium 1k", :iterations => iterations) {
        1000.times { YAML.dump(medium_data) }
      },
      BenchmarkRunner.run(:name => "YAML: load only medium 1k", :iterations => iterations) {
        dumped = YAML.dump(medium_data)
        1000.times { YAML.load(dumped) }
      }
    ]
  end

  # === LAZY EVALUATION ===
  def lazy_techniques(iterations)
    puts "\n--- Lazy: lazy vs eager evaluation ---"

    # Lazy requires Ruby 2.0+
    unless [].respond_to?(:lazy)
      puts "  [skipped] Lazy evaluation (requires Ruby 2.0+)"
      return []
    end

    data = (1..10000).to_a

    [
      BenchmarkRunner.run(:name => "LAZY: find (eager)", :iterations => iterations) {
        1000.times { data.find { |x| x > 5000 } }
      },
      BenchmarkRunner.run(:name => "LAZY: lazy.find", :iterations => iterations) {
        1000.times { data.lazy.find { |x| x > 5000 } }
      },
      BenchmarkRunner.run(:name => "LAZY: select.first (eager)", :iterations => iterations) {
        1000.times { data.select { |x| x > 5000 }.first }
      },
      BenchmarkRunner.run(:name => "LAZY: lazy.select.first", :iterations => iterations) {
        1000.times { data.lazy.select { |x| x > 5000 }.first }
      },
      BenchmarkRunner.run(:name => "LAZY: map.first 10 (eager)", :iterations => iterations) {
        1000.times { data.map { |x| x * 2 }.first(10) }
      },
      BenchmarkRunner.run(:name => "LAZY: lazy.map.first 10", :iterations => iterations) {
        1000.times { data.lazy.map { |x| x * 2 }.first(10) }
      }
    ]
  end

  # === GROUPING PATTERNS ===
  def grouping_techniques(iterations)
    puts "\n--- Grouping: group_by patterns ---"

    data = (1..10000).map { |i| { :id => i, :category => "cat#{i % 100}", :value => i } }

    [
      BenchmarkRunner.run(:name => "GROUP: group_by block 100", :iterations => iterations) {
        100.times { data.group_by { |h| h[:category] } }
      },
      BenchmarkRunner.run(:name => "GROUP: each_with_object 100", :iterations => iterations) {
        100.times {
          data.each_with_object({}) { |h, acc|
            (acc[h[:category]] ||= []) << h
          }
        }
      },
      BenchmarkRunner.run(:name => "GROUP: inject grouping 100", :iterations => iterations) {
        100.times {
          data.inject({}) { |acc, h|
            (acc[h[:category]] ||= []) << h
            acc
          }
        }
      },
      BenchmarkRunner.run(:name => "GROUP: partition 2 groups 100", :iterations => iterations) {
        simple = (1..10000).to_a
        100.times { simple.partition { |x| x.even? } }
      },
      BenchmarkRunner.run(:name => "GROUP: dual select 100", :iterations => iterations) {
        simple = (1..10000).to_a
        100.times {
          simple.select { |x| x.even? }
          simple.select { |x| x.odd? }
        }
      }
    ]
  end

  # === METAPROGRAMMING ===
  # NOTE: All benchmarks accumulate and return results to prevent JIT dead code elimination
  def metaprogramming_techniques(iterations)
    puts "\n--- Metaprogramming: dynamic method patterns ---"

    base_class = Class.new do
      def direct_method
        42
      end
    end

    # Pre-define dynamic methods
    dynamic_class = Class.new do
      define_method(:dynamic_method) { 42 }
    end

    obj_direct = base_class.new
    obj_dynamic = dynamic_class.new

    [
      BenchmarkRunner.run(:name => "META: def method call 100k", :iterations => iterations) {
        sum = 0
        100_000.times { sum += obj_direct.direct_method }
        sum
      },
      BenchmarkRunner.run(:name => "META: define_method call 100k", :iterations => iterations) {
        sum = 0
        100_000.times { sum += obj_dynamic.dynamic_method }
        sum
      },
      BenchmarkRunner.run(:name => "META: send 100k", :iterations => iterations) {
        sum = 0
        100_000.times { sum += obj_direct.send(:direct_method) }
        sum
      },
      BenchmarkRunner.run(:name => "META: respond_to?+send 100k", :iterations => iterations) {
        sum = 0
        100_000.times {
          sum += obj_direct.send(:direct_method) if obj_direct.respond_to?(:direct_method)
        }
        sum
      },
      BenchmarkRunner.run(:name => "META: method().call 100k", :iterations => iterations) {
        m = obj_direct.method(:direct_method)
        sum = 0
        100_000.times { sum += m.call }
        sum
      },
      BenchmarkRunner.run(:name => "META: ivar_get 100k", :iterations => iterations) {
        obj = Object.new
        obj.instance_variable_set(:@value, 42)
        sum = 0
        100_000.times { sum += obj.instance_variable_get(:@value) }
        sum
      },
      BenchmarkRunner.run(:name => "META: ivar_set 100k", :iterations => iterations) {
        obj = Object.new
        100_000.times { |i| obj.instance_variable_set(:@value, i) }
        obj.instance_variable_get(:@value)
      }
    ]
  end

  # === EXCEPTION HANDLING ===
  # NOTE: All benchmarks accumulate and return results to prevent JIT dead code elimination
  def exception_techniques(iterations)
    puts "\n--- Exceptions: error handling overhead ---"

    [
      BenchmarkRunner.run(:name => "EXC: no exception 100k", :iterations => iterations) {
        sum = 0
        100_000.times { sum += 1 + 1 }
        sum
      },
      BenchmarkRunner.run(:name => "EXC: begin/rescue none 100k", :iterations => iterations) {
        sum = 0
        100_000.times {
          begin
            sum += 1 + 1
          rescue
            sum += 0
          end
        }
        sum
      },
      BenchmarkRunner.run(:name => "EXC: raise/rescue 10k", :iterations => iterations) {
        count = 0
        10_000.times {
          begin
            raise "error"
          rescue
            count += 1
          end
        }
        count
      },
      BenchmarkRunner.run(:name => "EXC: raise/rescue msg 10k", :iterations => iterations) {
        total_len = 0
        10_000.times {
          begin
            raise StandardError, "error message"
          rescue => e
            total_len += e.message.length
          end
        }
        total_len
      },
      BenchmarkRunner.run(:name => "EXC: throw/catch 10k", :iterations => iterations) {
        sum = 0
        10_000.times {
          sum += catch(:done) { throw :done, 42 }
        }
        sum
      },
      BenchmarkRunner.run(:name => "EXC: nested throw/catch 10k", :iterations => iterations) {
        sum = 0
        10_000.times {
          sum += catch(:outer) {
            catch(:inner) {
              throw :outer, 42
            }
          }
        }
        sum
      }
    ]
  end

  # === STRING FREEZING/DEDUP ===
  # NOTE: All benchmarks accumulate and return results to prevent JIT dead code elimination
  def string_freeze_techniques(iterations)
    puts "\n--- String Freeze: deduplication patterns ---"

    results = []

    results << BenchmarkRunner.run(:name => "FREEZE: literal 100k", :iterations => iterations) {
      total_len = 0
      100_000.times { total_len += "hello".length }
      total_len
    }

    results << BenchmarkRunner.run(:name => "FREEZE: .freeze 100k", :iterations => iterations) {
      total_len = 0
      100_000.times { total_len += "hello".freeze.length }
      total_len
    }

    # -"string" only works in Ruby 2.3+ with frozen_string_literal
    if RUBY_VERSION >= "2.3"
      results << BenchmarkRunner.run(:name => "FREEZE: -\"\" dedup 100k", :iterations => iterations) {
        total_len = 0
        100_000.times { total_len += (-"hello").length }
        total_len
      }
    end

    results << BenchmarkRunner.run(:name => "FREEZE: dup 100k", :iterations => iterations) {
      s = "hello"
      total_len = 0
      100_000.times { total_len += s.dup.length }
      total_len
    }

    results << BenchmarkRunner.run(:name => "FREEZE: interpolate 100k", :iterations => iterations) {
      val = "world"
      total_len = 0
      100_000.times { total_len += "hello #{val}".length }
      total_len
    }

    results << BenchmarkRunner.run(:name => "FREEZE: interpolate.freeze 100k", :iterations => iterations) {
      val = "world"
      total_len = 0
      100_000.times { total_len += "hello #{val}".freeze.length }
      total_len
    }

    results
  end

  # === STRING SPLIT PATTERNS ===
  def split_techniques(iterations)
    puts "\n--- Split: String#split patterns ---"

    csv_line = "field1,field2,field3,field4,field5,field6,field7,field8,field9,field10"
    lines = "line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8\nline9\nline10"

    [
      BenchmarkRunner.run(:name => "SPLIT: split no limit 10k", :iterations => iterations) {
        10_000.times { csv_line.split(",") }
      },
      BenchmarkRunner.run(:name => "SPLIT: split limit 3 10k", :iterations => iterations) {
        10_000.times { csv_line.split(",", 3) }
      },
      BenchmarkRunner.run(:name => "SPLIT: split limit -1 10k", :iterations => iterations) {
        10_000.times { csv_line.split(",", -1) }
      },
      BenchmarkRunner.run(:name => "SPLIT: split newline 10k", :iterations => iterations) {
        10_000.times { lines.split("\n") }
      },
      BenchmarkRunner.run(:name => "SPLIT: each_line 10k", :iterations => iterations) {
        10_000.times { lines.each_line.to_a }
      },
      BenchmarkRunner.run(:name => "SPLIT: lines method 10k", :iterations => iterations) {
        10_000.times { lines.lines }
      },
      BenchmarkRunner.run(:name => "SPLIT: scan pattern 10k", :iterations => iterations) {
        10_000.times { csv_line.scan(/[^,]+/) }
      }
    ]
  end
end
