# encoding: utf-8
# frozen_string_literal: true

require 'set'

# Test: RubyStoreExt behavior compatibility with Ruby Hash
# Verifies that RubyStoreExt behaves identically to Hash

unless RUBY_ENGINE == 'jruby'
  puts "This test requires JRuby"
  exit 1
end

require 'java'

# Load RubyStoreExt
$CLASSPATH << File.expand_path('../../java/ruby_store_ext.jar', __FILE__)
Java::Default::RubyStoreExt.define(org.jruby.Ruby.getGlobalRuntime)

class RubyStoreExtTest
  def initialize
    @passed = 0
    @failed = 0
    @errors = []
  end

  def assert_equal(expected, actual, message = nil)
    if expected == actual
      @passed += 1
      print "."
    else
      @failed += 1
      @errors << "FAIL: #{message}\n  Expected: #{expected.inspect}\n  Actual:   #{actual.inspect}"
      print "F"
    end
  end

  def assert(condition, message = nil)
    if condition
      @passed += 1
      print "."
    else
      @failed += 1
      @errors << "FAIL: #{message}"
      print "F"
    end
  end

  def run_all
    puts "Running RubyStoreExt behavior tests...\n\n"

    test_basic_access
    test_size_methods
    test_key_value_checks
    test_iteration
    test_keys_values
    test_modification
    test_conversion
    test_fetch
    test_merge
    test_insertion_order

    puts "\n\n#{'=' * 50}"
    puts "Results: #{@passed} passed, #{@failed} failed"

    if @errors.any?
      puts "\nFailures:"
      @errors.each { |e| puts "\n#{e}" }
    end

    puts "#{'=' * 50}"
    exit(@failed > 0 ? 1 : 0)
  end

  def test_basic_access
    print "Basic access: "
    h = { "a" => 1, "b" => 2, "c" => 3 }
    s = RubyStoreExt.new
    s["a"] = 1; s["b"] = 2; s["c"] = 3

    assert_equal h["a"], s["a"], "[] read existing key"
    assert_equal h["z"], s["z"], "[] read missing key"
    assert_equal h.size, s.size, "size after creation"

    h["d"] = 4
    s["d"] = 4
    assert_equal h["d"], s["d"], "[] write and read"
    assert_equal h.size, s.size, "size after write"
    puts
  end

  def test_size_methods
    print "Size methods: "
    h = { a: 1, b: 2, c: 3 }
    s = RubyStoreExt.new
    s[:a] = 1; s[:b] = 2; s[:c] = 3

    assert_equal h.size, s.size, "size"
    assert_equal h.length, s.length, "length"
    assert_equal h.empty?, s.empty?, "empty? when not empty"

    h2 = {}
    s2 = RubyStoreExt.new
    assert_equal h2.empty?, s2.empty?, "empty? when empty"
    puts
  end

  def test_key_value_checks
    print "Key/value checks: "
    h = { "a" => 1, "b" => 2, "c" => 3 }
    s = RubyStoreExt.new
    s["a"] = 1; s["b"] = 2; s["c"] = 3

    assert_equal h.key?("a"), s.key?("a"), "key? existing"
    assert_equal h.key?("z"), s.key?("z"), "key? missing"
    assert_equal h.has_key?("b"), s.has_key?("b"), "has_key?"
    assert_equal h.include?("c"), s.include?("c"), "include?"
    assert_equal h.member?("a"), s.member?("a"), "member?"

    assert_equal h.value?(1), s.value?(1), "value? existing"
    assert_equal h.value?(99), s.value?(99), "value? missing"
    assert_equal h.has_value?(2), s.has_value?(2), "has_value?"
    puts
  end

  def test_iteration
    print "Iteration: "
    h = { "a" => 1, "b" => 2, "c" => 3 }
    s = RubyStoreExt.new
    s["a"] = 1; s["b"] = 2; s["c"] = 3

    # each
    h_pairs = []; h.each { |k, v| h_pairs << [k, v] }
    s_pairs = []; s.each { |k, v| s_pairs << [k, v] }
    assert_equal h_pairs.sort, s_pairs.sort, "each yields same pairs"

    # each_key
    h_keys = []; h.each_key { |k| h_keys << k }
    s_keys = []; s.each_key { |k| s_keys << k }
    assert_equal h_keys.sort, s_keys.sort, "each_key yields same keys"

    # each_value
    h_vals = []; h.each_value { |v| h_vals << v }
    s_vals = []; s.each_value { |v| s_vals << v }
    assert_equal h_vals.sort, s_vals.sort, "each_value yields same values"

    # map
    h_map = h.map { |k, v| v * 2 }
    s_map = s.map { |k, v| v * 2 }
    assert_equal h_map.sort, s_map.sort, "map returns same results"

    # select
    h_sel = h.select { |k, v| v > 1 }
    s_sel = s.select { |k, v| v > 1 }
    assert_equal h_sel.to_a.sort, s_sel.to_a.sort, "select returns same results"

    # reject
    h_rej = h.reject { |k, v| v > 1 }
    s_rej = s.reject { |k, v| v > 1 }
    assert_equal h_rej.to_a.sort, s_rej.to_a.sort, "reject returns same results"
    puts
  end

  def test_keys_values
    print "Keys/values: "
    h = { "a" => 1, "b" => 2, "c" => 3 }
    s = RubyStoreExt.new
    s["a"] = 1; s["b"] = 2; s["c"] = 3

    assert_equal h.keys.sort, s.keys.sort, "keys"
    assert_equal h.values.sort, s.values.sort, "values"

    assert_equal h.values_at("a", "c"), s.values_at("a", "c"), "values_at existing"
    assert_equal h.values_at("a", "z"), s.values_at("a", "z"), "values_at with missing"
    puts
  end

  def test_modification
    print "Modification: "
    h = { "a" => 1, "b" => 2, "c" => 3 }
    s = RubyStoreExt.new
    s["a"] = 1; s["b"] = 2; s["c"] = 3

    # delete
    assert_equal h.delete("b"), s.delete("b"), "delete existing"
    assert_equal h.size, s.size, "size after delete"
    assert_equal h.delete("z"), s.delete("z"), "delete missing"

    # clear
    h2 = { x: 1, y: 2 }
    s2 = RubyStoreExt.new; s2[:x] = 1; s2[:y] = 2
    h2.clear
    s2.clear
    assert_equal h2.size, s2.size, "size after clear"
    assert_equal h2.empty?, s2.empty?, "empty? after clear"

    # store
    h3 = {}
    s3 = RubyStoreExt.new
    h3.store("key", "value")
    s3.store("key", "value")
    assert_equal h3["key"], s3["key"], "store method"
    puts
  end

  def test_conversion
    print "Conversion: "
    h = { "a" => 1, "b" => 2, "c" => 3 }
    s = RubyStoreExt.new
    s["a"] = 1; s["b"] = 2; s["c"] = 3

    # to_a
    assert_equal h.to_a.sort, s.to_a.sort, "to_a"

    # flatten (can't sort mixed types, compare sets instead)
    assert_equal h.flatten.to_set, s.flatten.to_set, "flatten"

    # invert
    h_inv = h.invert
    s_inv = s.invert
    assert_equal h_inv.to_a.sort, s_inv.to_a.sort, "invert"

    # to_h / to_hash
    h_h = s.to_h
    assert h_h.is_a?(Hash), "to_h returns Hash"
    assert_equal h.to_a.sort, h_h.to_a.sort, "to_h content"
    puts
  end

  def test_fetch
    print "Fetch: "
    h = { "a" => 1, "b" => 2 }
    s = RubyStoreExt.new
    s["a"] = 1; s["b"] = 2

    assert_equal h.fetch("a"), s.fetch("a"), "fetch existing"
    assert_equal h.fetch("z", 99), s.fetch("z", 99), "fetch with default"
    assert_equal h.fetch("z") { |k| k.upcase }, s.fetch("z") { |k| k.upcase }, "fetch with block"

    # fetch missing without default should raise
    h_raised = false
    s_raised = false
    begin; h.fetch("missing"); rescue KeyError; h_raised = true; end
    begin; s.fetch("missing"); rescue; s_raised = true; end
    assert h_raised && s_raised, "fetch missing raises error"
    puts
  end

  def test_merge
    print "Merge: "
    h1 = { "a" => 1, "b" => 2 }
    s1 = RubyStoreExt.new; s1["a"] = 1; s1["b"] = 2

    h2 = { "b" => 20, "c" => 3 }
    s2 = RubyStoreExt.new; s2["b"] = 20; s2["c"] = 3

    h_merged = h1.merge(h2)
    s_merged = s1.merge(s2)

    assert_equal h_merged.to_a.sort, s_merged.to_a.sort, "merge result"
    assert_equal h1.size, s1.size, "original unchanged after merge"

    # merge!
    h3 = { "x" => 1 }
    s3 = RubyStoreExt.new; s3["x"] = 1
    h3.merge!({ "y" => 2 })
    s3.merge!(RubyStoreExt.new.tap { |x| x["y"] = 2 })
    assert_equal h3.to_a.sort, s3.to_a.sort, "merge! result"
    puts
  end

  def test_insertion_order
    print "Insertion order: "
    h = {}
    s = RubyStoreExt.new

    # Insert in specific order
    %w[first second third fourth fifth].each_with_index do |k, i|
      h[k] = i
      s[k] = i
    end

    assert_equal h.keys, s.keys, "keys preserve insertion order"
    assert_equal h.values, s.values, "values preserve insertion order"

    # to_a preserves order
    assert_equal h.to_a, s.to_a, "to_a preserves insertion order"

    # each preserves order
    h_order = []; h.each { |k, v| h_order << k }
    s_order = []; s.each { |k, v| s_order << k }
    assert_equal h_order, s_order, "each preserves insertion order"
    puts
  end
end

if __FILE__ == $0
  RubyStoreExtTest.new.run_all
end
