#!/usr/bin/env ruby
# Initialize a key/value database repo
# Copyright 2011 Thoughtgang <http://www.thoughtgang.org>

BASE=File.dirname(File.expand_path(__FILE__)\
                 ).split(File::SEPARATOR)[0..-4].join(File::SEPARATOR)
$: << BASE + File::SEPARATOR + 'lib'
$: << BASE + File::SEPARATOR + 'doc' + File::SEPARATOR + 'examples'

require 'key_value/model'

if __FILE__ == $0
  if ARGV.count != 1 
    puts "Usage : #{$0} FILENAME"
    exit -1
  end 

  KeyValueModel.new(GitDS::Database.connect(ARGV.shift, true))
  exit 0
end
