#!/usr/bin/env ruby
# Add a Test to a TestSuite database repo
# Copyright 2011 Thoughtgang <http://www.thoughtgang.org>

# Add examples dir and lib/git-ds to ruby path
BASE=File.dirname(File.expand_path(__FILE__)\
                 ).split(File::SEPARATOR)[0..-4].join(File::SEPARATOR)
$: << BASE + File::SEPARATOR + 'lib'
$: << BASE + File::SEPARATOR + 'doc' + File::SEPARATOR + 'examples'

require 'test_suite/model'
require 'optparse'
require 'ostruct'

def get_options(args)
  options = OpenStruct.new

  options.db = nil
  options.auto = false
  options.suite = nil
  options.ident = nil
  options.modules = []

  opts = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [-p db_path] SUITE_IDENT TEST_IDENT [MODULE...]"
    opts.separator 'Add a Test to Test Suite in database'
    opts.separator 'Options:'

    opts.on( '-p', '--db-path PATH', 'Path to TestSuite GitDS' ) do |path| 
      options.db = path
      options.auto = true
    end

    opts.on_tail( '-?', '--help', 'Show this message') do
      puts opts
      exit -1
    end
  end

  opts.parse!(args)

  options.db = GitDS::Database.top_level if not options.db
  raise "Invalid database" if not options.db

  if args.count >= 2
    options.suite = args.shift
    options.ident = args.shift
    args.each { |m| options.modules << m }
  else
    puts opts.banner
    exit -2
  end

  options
end

# ----------------------------------------------------------------------
if __FILE__ == $0
  options = get_options(ARGV)

  model = TestSuiteModel.new(GitDS::Database.connect(options.db, options.auto))
  raise "Could not connect to Model!" if not model

  s = model.test_suite(options.suite)
  raise "Could not find TestSuite #{options.suite}" if not s

  mods = []
  options.modules.each do |ident|
    m = model.module(ident)
    raise "Module #{m} not found" if not m
    mods << m
  end

  s.add_test(options.ident, mods)

  exit 0
end
