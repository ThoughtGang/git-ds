#!/usr/bin/env ruby
# Set results for performing a Test in a TestSuite database repo
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
  options.user = nil
  options.email = nil
  options.ident = nil
  options.suite = nil
  options.passed = nil
  options.log = ''

  opts = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [-tf] [-elpu arg] SUITE_IDENT TEST_IDENT " +
                  "[0|1]"
    opts.separator 'Set results for performing a Test'
    opts.separator 'Note: A trailing arg of 0 (success) or nonzero (failure)'
    opts.separator '      is expected if neither -t nor -f is present.'
    opts.separator 'Options:'

    opts.on( '-p', '--db-path PATH', 'Path to TestSuite GitDS' ) do |path| 
      options.db = path
      options.auto = true
    end

    opts.on( '-l', '--log str', 'Log entry for test' ) do |str| 
      options.log = str
    end

    opts.on( '-u', '--user name', 'Name of Git user' ) do |name| 
      options.user = name
    end

    opts.on( '-e', '--email str', 'Email of Git user' ) do |str| 
      options.email = str
    end

    opts.on( '-t', '--true', 'Test succeeded') { options.passed = true }
    opts.on( '-f', '--false', 'Test failed') { options.passed = false }

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

    if options.passed == nil
      if args.count == 0
        puts opts.banner
        exit -3
      end
      options.passed = (args.shift.to_i == 0)
    end
  else
    puts opts.banner
    exit -2
  end

  options
end

# ----------------------------------------------------------------------
if __FILE__ == $0
  options = get_options(ARGV)

  model = TestSuiteModel.new(GitDS::Database.connect_as(options.db, 
                                                        options.user,
                                                        options.email,
                                                        options.auto))
  raise "Could not connect to Model!" if not model

  s = model.test_suite(options.suite)
  raise "Could not find TestSuite #{options.suite}" if not s

  t = s.test(options.ident)
  raise "Could not find Test #{options.ident}" if not t

  t.perform( options.passed, options.log )

  exit 0
end
