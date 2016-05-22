#!/usr/bin/env ruby
# Add a user to a group in a User/Group database repo
# Copyright 2011 Thoughtgang <http://www.thoughtgang.org>

# Add examples dir and lib/git-ds to ruby path
BASE=File.dirname(File.expand_path(__FILE__)\
                 ).split(File::SEPARATOR)[0..-4].join(File::SEPARATOR)
$: << BASE + File::SEPARATOR + 'lib'
$: << BASE + File::SEPARATOR + 'doc' + File::SEPARATOR + 'examples'

require 'user_group/model'

if __FILE__ == $0
  if ARGV.count < 2 || ARGV.count > 3
    puts "Usage : #{$0} [FILENAME] GROUP USER"
    puts "Repo dir is assumed to be . if FILENAME is not specified."
    exit -1
  end 

  path = (ARGV.count == 3) ? ARGV.shift : GitDS::Database.top_level
  group_name = ARGV.shift
  user_name = ARGV.shift

  model = UserGroupModel.new(GitDS::Database.connect(path, false))
  raise "Could not connect to Model!" if not model

  g = model.group(group_name)
  raise "Invalid group #{group_name}" if not g

  u = model.user(user_name)
  raise "Invalid user #{user_name}" if not u

  g.add_user(u)

  exit 0
end
