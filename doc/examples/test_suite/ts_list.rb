#!/usr/bin/env ruby
# List contents of a TestSuite database repo
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
  options.suites = false
  options.modules = false
  options.bugs = false
  options.details = false

  opts = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [-p db_path] [-bdsm]"
    opts.separator 'Add a TestSuite to database'
    opts.separator 'Options:'

    opts.on( '-p', '--db-path PATH', 'Path to TestSuite GitDS' ) do |path| 
      options.db = path
    end

    opts.on( '-b', '--bugs', 'List bugs' ) { options.bugs = true }
    opts.on( '-d', '--details', 'Show details' ) { options.details = true }
    opts.on( '-s', '--suites', 'List test suites' ) { options.suites = true }
    opts.on( '-m', '--modules', 'List modules' ) { options.modules = true }

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

def list_modules(model, details)
  puts "Modules:"
  model.modules.each do |ident|
    puts "\t" + ident
    if details
      m = model.module(ident)
      puts "\t\t" + m.name
      puts "\t\t" + m.path
      puts "\t\tContents:"
      puts "\t\t" + m.data[0,60] + (m.data.length > 60 ? '...' : '')
    end
  end
end

def list_suites(model, details)
  puts "Test Suites:"
  model.test_suites.each do |ident|
    puts "\t" + ident
    if details
      s = model.test_suite(ident)
      puts "\t\t" + s.description
      puts "\t\tTests:"
      s.tests.each do |ident|
        t = s.test(ident)
        puts "\t\t\t" + ident
        puts "\t\t\t" + ((t.pass?) ? 'Passed' : 'Failed')
        puts "\t\t\t" + t.timestamp.to_s
        puts "\t\t\tModules:"
        t.modules.each { |ident| puts "\t\t\t\t" + ident }
        puts "\t\t\tLog:\n" + t.log
      end
    end
  end
end

def list_bugs(model, details)
  puts "Bugs:"
  model.bugs.each do |ident|
    puts "\t" + ident
    if details
      b = model.bug(ident)
      puts "\t\t" + b.description
      puts "\t\t" + ((b.open?) ? 'Open' : 'Closed')
      puts "\t\tTests:"
      b.tests.each { |ident| puts "\t\t\t" + ident }
    end
  end
end

# ----------------------------------------------------------------------
if __FILE__ == $0
  options = get_options(ARGV)

  model = TestSuiteModel.new(GitDS::Database.connect(options.db, options.auto))
  raise "Could not connect to Model!" if not model

  list_modules(model, options.details) if options.modules
  list_suites(model, options.details) if options.suites
  list_bugs(model, options.details) if options.bugs

  exit 0
end
