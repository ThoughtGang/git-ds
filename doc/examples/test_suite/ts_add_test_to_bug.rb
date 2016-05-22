#!/usr/bin/env ruby
# Add a Test to a Bug in a TestSuite database repo
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
  options.bug = nil
  options.suite = nil
  options.ident = nil

  opts = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [-p db_path] BUG_IDENT SUITE_IDENT TEST_IDENT"
    opts.separator 'Add a Test to Bug Report in database'
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

  if args.count == 3
    options.bug = args.shift
    options.suite = args.shift
    options.ident = args.shift
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

  b = model.bug(options.bug)
  raise "Could not find Bug #{options.bug}" if not b

  s = model.test_suite(options.suite)
  raise "Could not find TestSuite #{options.suite}" if not s

  t = s.test(options.ident)
  raise "Could not find Test #{options.ident}" if not t

  b.add_test(t)

  exit 0
end
