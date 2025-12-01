# encoding: utf-8
# frozen_string_literal: true
# Compatibility detection for Ruby 1.9.3 (JRuby 1.7)
# No polyfills - just version detection for conditional benchmark skipping

RUBY_19 = RUBY_VERSION < '2.0'
RUBY_20 = RUBY_VERSION >= '2.0'
RUBY_21 = RUBY_VERSION >= '2.1'
RUBY_22 = RUBY_VERSION >= '2.2'
RUBY_23 = RUBY_VERSION >= '2.3'
RUBY_24 = RUBY_VERSION >= '2.4'
RUBY_27 = RUBY_VERSION >= '2.7'

# Feature availability checks
HAS_ARRAY_SUM = Array.method_defined?(:sum)
HAS_ITSELF = Object.method_defined?(:itself)
HAS_ARRAY_TO_H = Array.method_defined?(:to_h)
HAS_HASH_DIG = Hash.method_defined?(:dig)
HAS_STRING_MATCH_Q = String.method_defined?(:match?)
HAS_FILTER_MAP = Enumerable.method_defined?(:filter_map)
HAS_CLOCK_MONOTONIC = defined?(Process::CLOCK_MONOTONIC)
