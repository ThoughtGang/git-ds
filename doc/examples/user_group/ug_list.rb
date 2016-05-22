#!/usr/bin/env ruby
# List User/Group database contents
# Copyright 2011 Thoughtgang <http://www.thoughtgang.org>

BASE=File.dirname(File.expand_path(__FILE__)\
                 ).split(File::SEPARATOR)[0..-4].join(File::SEPARATOR)
$: << BASE + File::SEPARATOR + 'lib'
$: << BASE + File::SEPARATOR + 'doc' + File::SEPARATOR + 'examples'

require 'user_group/model'

if __FILE__ == $0

  path = ARGV.count == 1 ? ARGV.shift : GitDS::Database.top_level
  model = UserGroupModel.new(GitDS::Database.connect(path, false))
  raise "Could not connect to model" if not model

  puts "Users:"
  model.users.each do |user|
    u = model.user(user)
    puts "\t#{u.id}\t#{u.username}\t#{u.created}\t#{u.full_name}"
  end

  puts "\nGroups:"
  model.groups.each do |grp|
    puts "\t#{grp}"
    g = model.group(grp)
    puts "\t#{g.id}\t#{g.name}\t#{g.owner.username}\t#{g.users.inspect}"
  end

  exit 0
end
