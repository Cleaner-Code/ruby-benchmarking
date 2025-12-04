# encoding: utf-8
# frozen_string_literal: true

require_relative '../lib/benchmark_runner'

# String operation benchmarks (not building comparisons - those are in technique_benchmarks.rb)
module StringBenchmarks
  extend self

  def run_all(options = {})
    iterations = options[:iterations] || 10
    results = []

    puts "\n#{'=' * 70}"
    puts "STRING OPERATION BENCHMARKS - #{BenchmarkRunner.ruby_version_info}"
    puts "#{'=' * 70}"

    results << string_split(:iterations => iterations)
    results << string_gsub(:iterations => iterations)
    results << string_scan(:iterations => iterations)
    results << string_match(:iterations => iterations)
    results << string_encoding(:iterations => iterations)
    results << string_frozen(:iterations => iterations)

    results
  end

  def string_split(options = {})
    iterations = options[:iterations] || 10
    sample_text = (["word"] * 1_000).join(" ") * 5

    BenchmarkRunner.run(:name => "String#split", :iterations => iterations) do
      500.times { sample_text.split(" ") }
    end
  end

  def string_gsub(options = {})
    iterations = options[:iterations] || 10
    sample_text = "The quick brown fox jumps over the lazy dog. " * 500

    BenchmarkRunner.run(:name => "String#gsub (regex)", :iterations => iterations) do
      500.times { sample_text.gsub(/[aeiou]/, '*') }
    end
  end

  def string_scan(options = {})
    iterations = options[:iterations] || 10
    sample_text = "abc123def456ghi789" * 1_000

    BenchmarkRunner.run(:name => "String#scan (regex)", :iterations => iterations) do
      500.times { sample_text.scan(/\d+/) }
    end
  end

  def string_match(options = {})
    iterations = options[:iterations] || 10
    sample_text = "The quick brown fox jumps over the lazy dog"
    regex = /(\w+)\s+(\w+)\s+(\w+)/

    BenchmarkRunner.run(:name => "String#match", :iterations => iterations) do
      100_000.times { sample_text.match(regex) }
    end
  end

  def string_encoding(options = {})
    iterations = options[:iterations] || 10
    sample_utf8 = "Hello World Test String " * 100

    BenchmarkRunner.run(:name => "String encoding conversion", :iterations => iterations) do
      2_000.times do
        s = sample_utf8.encode('UTF-16LE')
        s.encode('UTF-8')
      end
    end
  end

  def string_frozen(options = {})
    iterations = options[:iterations] || 10
    BenchmarkRunner.run(:name => "Frozen string literals", :iterations => iterations) do
      result = []
      100_000.times do
        result << "frozen_string".freeze
      end
    end
  end
end

if __FILE__ == $0
  StringBenchmarks.run_all.each do |result|
    puts result.to_h.to_json
  end
end
