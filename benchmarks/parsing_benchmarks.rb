# encoding: utf-8
# frozen_string_literal: true

require_relative '../lib/benchmark_runner'
require 'json'
require 'csv'

module ParsingBenchmarks
  extend self

  def run_all(options = {})
    iterations = options[:iterations] || 10
    results = []

    puts "\n#{'='*70}"
    puts "PARSING BENCHMARKS - #{BenchmarkRunner.ruby_version_info}"
    puts "#{'='*70}"

    results << json_parse(:iterations => iterations)
    results << json_generate(:iterations => iterations)
    results << csv_parse(:iterations => iterations)
    results << csv_generate(:iterations => iterations)
    results << integer_parse(:iterations => iterations)
    results << float_parse(:iterations => iterations)
    results << date_parse(:iterations => iterations)
    results << regex_extraction(:iterations => iterations)
    results << tokenization(:iterations => iterations)
    results << line_parsing(:iterations => iterations)

    results
  end

  def json_parse(options = {})
    iterations = options[:iterations] || 10
    data = {
      :users => (1..50).map do |i|
        {
          :id => i,
          :name => "User #{i}",
          :email => "user#{i}@example.com",
          :tags => ["tag1", "tag2", "tag3"],
          :metadata => { :created => "2024-01-01", :active => true }
        }
      end
    }
    json_str = JSON.generate(data)

    BenchmarkRunner.run(:name => "JSON.parse", :iterations => iterations) do
      2_000.times { JSON.parse(json_str) }
    end
  end

  def json_generate(options = {})
    iterations = options[:iterations] || 10
    data = {
      :users => (1..50).map do |i|
        {
          :id => i,
          :name => "User #{i}",
          :email => "user#{i}@example.com",
          :tags => ["tag1", "tag2", "tag3"],
          :metadata => { :created => "2024-01-01", :active => true }
        }
      end
    }

    BenchmarkRunner.run(:name => "JSON.generate", :iterations => iterations) do
      2_000.times { JSON.generate(data) }
    end
  end

  def csv_parse(options = {})
    iterations = options[:iterations] || 10
    csv_data = CSV.generate do |csv|
      csv << ["id", "name", "email", "age", "city"]
      500.times do |i|
        csv << [i, "Name #{i}", "email#{i}@example.com", 20 + (i % 50), "City #{i % 100}"]
      end
    end

    BenchmarkRunner.run(:name => "CSV.parse", :iterations => iterations) do
      100.times { CSV.parse(csv_data) }
    end
  end

  def csv_generate(options = {})
    iterations = options[:iterations] || 10
    data = []
    500.times do |i|
      data << [i, "Name #{i}", "email#{i}@example.com", 20 + (i % 50), "City #{i % 100}"]
    end

    BenchmarkRunner.run(:name => "CSV.generate", :iterations => iterations) do
      100.times do
        CSV.generate do |csv|
          csv << ["id", "name", "email", "age", "city"]
          data.each { |row| csv << row }
        end
      end
    end
  end

  def integer_parse(options = {})
    iterations = options[:iterations] || 10
    strings = []
    5_000.times { |i| strings << (i * 12345).to_s }

    BenchmarkRunner.run(:name => "Integer() parsing", :iterations => iterations) do
      20.times { strings.each { |s| Integer(s) } }
    end
  end

  def float_parse(options = {})
    iterations = options[:iterations] || 10
    strings = []
    5_000.times { |i| strings << "#{i}.#{rand(1000)}" }

    BenchmarkRunner.run(:name => "Float() parsing", :iterations => iterations) do
      20.times { strings.each { |s| Float(s) } }
    end
  end

  def date_parse(options = {})
    iterations = options[:iterations] || 10
    require 'date'
    dates = []
    500.times { |i| dates << "2024-#{(i % 12) + 1}-#{(i % 28) + 1}" }

    BenchmarkRunner.run(:name => "Date.parse", :iterations => iterations) do
      20.times { dates.each { |d| Date.parse(d) } }
    end
  end

  def regex_extraction(options = {})
    iterations = options[:iterations] || 10
    log_lines = []
    2_000.times do |i|
      log_lines << "[2024-01-15 12:#{i % 60}:#{i % 60}] INFO: User #{i} performed action_#{i % 10}"
    end
    pattern = /\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\] (\w+): User (\d+) performed (\w+)/

    BenchmarkRunner.run(:name => "Regex extraction", :iterations => iterations) do
      5.times do
        log_lines.each do |line|
          m = line.match(pattern)
          if m
            [m[1], m[2], m[3], m[4]]
          end
        end
      end
    end
  end

  def tokenization(options = {})
    iterations = options[:iterations] || 10
    code_samples = []
    200.times do |i|
      code_samples << "def method_#{i}(arg1, arg2)\n  result = arg1 + arg2\n  puts \"Result: \#{result}\"\n  return result\nend"
    end
    code_text = code_samples.join("\n\n")

    BenchmarkRunner.run(:name => "Tokenization (scan)", :iterations => iterations) do
      20.times do
        tokens = code_text.scan(/\b\w+\b|[^\s\w]/)
      end
    end
  end

  def line_parsing(options = {})
    iterations = options[:iterations] || 10
    lines = []
    20_000.times { |i| lines << "line #{i}: #{rand(1000)} data points" }
    text = lines.join("\n")

    BenchmarkRunner.run(:name => "Line-by-line parsing", :iterations => iterations) do
      5.times do
        text.each_line do |line|
          parts = line.split(":")
          parts[0].strip
          parts[1].strip if parts[1]
        end
      end
    end
  end
end

if __FILE__ == $0
  ParsingBenchmarks.run_all.each do |result|
    puts result.to_h.to_json
  end
end
