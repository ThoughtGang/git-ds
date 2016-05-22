#!/usr/bin/env ruby
# Test User/Group database example
# Copyright 2011 Thoughtgang <http://www.thoughtgang.org>

BASE=File.dirname(File.expand_path(__FILE__)\
                 ).split(File::SEPARATOR)[0..-4].join(File::SEPARATOR)
$: << BASE + File::SEPARATOR + 'lib'
$: << BASE + File::SEPARATOR + 'doc' + File::SEPARATOR + 'examples'

require 'user_group/model'

# ----------------------------------------------------------------------

def fill_model(model)
  users = [{ :username => 'root', :id => 1 },
           { :username => 'admin', :id => 1000, :full_name => 'Administrator'},
           { :username => 'humpty', :id => 1001, :full_name => 'H Umpty, Esq.'},
           { :username => 'dumpty', :id => 1002, :full_name => 'Dump Ty'}
          ]
  groups = [ { :name => 'wheel', :id => 1, :owner_name => 'root',
               :members => ['root', 'admin'] },
             { :name => 'staff', :id => 1000, :owner_name => 'admin',
               :members => ['admin', 'humpty', 'dumpty'] },
             { :name => 'twins', :id => 1001, :owner_name => 'humpty',
               :members => ['humpty', 'dumpty'] }
           ]

  users.each do |udef|
    model.add_user(udef[:username], udef[:id], udef[:full_name])
  end

  groups.each do |gdef|
    g = model.add_group(gdef[:name], gdef[:id], gdef[:owner_name])
    gdef[:members].each { |name| g.add_user(model.user(name)) }
  end

end

# ----------------------------------------------------------------------
def list_model(model)
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
end

# ----------------------------------------------------------------------
if __FILE__ == $0
  path = (ARGV.count > 0) ? ARGV.shift : 'ug_test.db'

  db = GitDS::Database.connect(path, true)
  model = UserGroupModel.new(db) if db
  fill_model(model) if model
  list_model(model) if model
end

