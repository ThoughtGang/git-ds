#!/usr/bin/env ruby
# Add a group to a User/Group database repo
# Copyright 2011 Thoughtgang <http://www.thoughtgang.org>

# Add examples dir and lib/git-ds to ruby path
BASE=File.dirname(File.expand_path(__FILE__)\
                 ).split(File::SEPARATOR)[0..-4].join(File::SEPARATOR)
$: << BASE + File::SEPARATOR + 'lib'
$: << BASE + File::SEPARATOR + 'doc' + File::SEPARATOR + 'examples'

require 'user_group/model'

if __FILE__ == $0
  if ARGV.count < 3 || ARGV.count > 4
    puts "Usage : #{$0} [FILENAME] NAME ID OWNER"
    puts "Repo dir is assumed to be . if FILENAME is not specified."
    puts "A new GitDS database will be created if FILENAME does not exist."
    exit -1
  end 

  path = ''
  autocreate = false
  if ARGV.count == 4
    path = ARGV.shift
    autocreate = true
  else
    path = GitDS::Database.top_level
  end
  name = ARGV.shift
  id = ARGV.shift
  owner = ARGV.shift

  model = UserGroupModel.new(GitDS::Database.connect(path, autocreate))
  raise "Could not connect to Model!" if not model

  model.add_group(name, id, owner)

  exit 0
end
