#!/usr/bin/env ruby
# Get a key:value pair from a database repo
# Copyright 2011 Thoughtgang <http://www.thoughtgang.org>

# Add examples dir and lib/git-ds to ruby path
BASE=File.dirname(File.expand_path(__FILE__)\
                 ).split(File::SEPARATOR)[0..-4].join(File::SEPARATOR)
$: << BASE + File::SEPARATOR + 'lib'
$: << BASE + File::SEPARATOR + 'doc' + File::SEPARATOR + 'examples'

require 'key_value/model'

if __FILE__ == $0
  if ARGV.count < 1 || ARGV.count > 2
    puts "Usage : #{$0} [FILENAME] KEY"
    puts "Repo dir is assumed to be . if FILENAME is not specified."
    exit -1
  end 

  path = (ARGV.count == 2) ? ARGV.shift : GitDS::Database.top_level
  key = ARGV.shift

  model = KeyValueModel.new(GitDS::Database.connect(path, false))
  raise "Could not connect to Model!" if not model

  puts model[key]

  exit 0
end
