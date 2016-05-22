#!/usr/bin/env ruby
# Add a Module (file) to a TestSuite database repo
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
  options.path = nil
  options.data = nil

  opts = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [-p db_path] [-d data] MODULE_PATH"
    opts.separator 'Add a module (source code file) to database'
    opts.separator 'Options:'

    opts.on( '-p', '--db-path PATH', 'Path to TestSuite GitDS' ) do |path| 
      options.db = path
      options.auto = true
    end

    opts.on( '-d', '--data=STR', 'Contents of module' ) do |str| 
      options.data = str
    end

    opts.on_tail( '-?', '--help', 'Show this message') do
      puts opts
      exit -1
    end
  end

  opts.parse!(args)

  options.db = GitDS::Database.top_level if not options.db
  raise "Invalid database" if not options.db

  if args.count > 0
    options.path = args.shift
    if not options.data
      options.data = File.exist?(options.path) ? 
                                (File.open(options.path){ |f| f.read }) : nil 
    end
  else
    puts opts.banner
    exit -2
  end

  raise "No data available for module '#{options.path}'" if not options.data

  options
end

# ----------------------------------------------------------------------
if __FILE__ == $0
  options = get_options(ARGV)

  model = TestSuiteModel.new(GitDS::Database.connect(options.db, options.auto))
  raise "Could not connect to Model!" if not model

  model.add_module(options.path, options.data)

  exit 0
end
