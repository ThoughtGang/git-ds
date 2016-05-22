#!/usr/bin/env ruby
# Set a key:value pair in a database repo
# Copyright 2011 Thoughtgang <http://www.thoughtgang.org>

# Add examples dir and lib/git-ds to ruby path
BASE=File.dirname(File.expand_path(__FILE__)\
                 ).split(File::SEPARATOR)[0..-4].join(File::SEPARATOR)
$: << BASE + File::SEPARATOR + 'lib'
$: << BASE + File::SEPARATOR + 'doc' + File::SEPARATOR + 'examples'

require 'key_value/model'

if __FILE__ == $0
  if ARGV.count < 2 || ARGV.count > 3
    puts "Usage : #{$0} [FILENAME] KEY VALUE"
    puts "Repo dir is assumed to be . if FILENAME is not specified."
    puts "A new GitDS database will be created if FILENAME does not exist."
    exit -1
  end 

  path = ''
  autocreate = false
  if ARGV.count == 3
    path = ARGV.shift
    autocreate = true
  else
    path = GitDS::Database.top_level
  end
  key = ARGV.shift
  val = ARGV.shift

  model = KeyValueModel.new(GitDS::Database.connect(path, autocreate))
  raise "Could not connect to Model!" if not model

  # Note: this will automatically be committed:
  model[key] = val

  exit 0
end
