#!/usr/bin/env ruby
# Update Bugs in a TestSuite database repo based on status of Tests
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

  opts = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [-p db_path]"
    opts.separator 'Update all bugs in database'
    opts.separator 'Options:'

    opts.on( '-p', '--db-path PATH', 'Path to TestSuite GitDS' ) do |path| 
      options.db = path
    end

    opts.on_tail( '-?', '--help', 'Show this message') do
      puts opts
      exit -1
    end
  end

  opts.parse!(args)

  options.db = GitDS::Database.top_level if not options.db
  raise "Invalid database" if not options.db

  # by default show all
  if (! options.bugs) && (! options.modules) && (! options.suites)
    options.bugs = options.modules = options.suites = true
  end

  options
end

# ----------------------------------------------------------------------
if __FILE__ == $0
  options = get_options(ARGV)

  model = TestSuiteModel.new(GitDS::Database.connect(options.db, options.auto))
  raise "Could not connect to Model!" if not model

  model.update_bugs

  exit 0
end
