#!/usr/bin/env ruby
# :title: GitDS Model Example: User/Group
=begin rdoc
<i>Copyright 2011 Thoughtgang <http://www.thoughtgang.org></i>

This example demonstrates a simple hierarchical data model for managing 
unix-style users and groups.

Note: This is not intended as a serious implementation of an auth system. It is
intended only to illustrate the use of a hierarchical database using a
familiar data model.

==Usage

An example of the usage of this model can be found in the following script:

    doc/examples/user_group/test.rb

This script can be run to generate an example Git-DS repository:

    bash$ doc/examples/user_group/test.rb
    bash$ cd ug_test.db && qgit &

The following command-line utilities are provided for manipulating this 
data model:

    doc/examples/user_group/ug_add_group.rb
    doc/examples/user_group/ug_add_group_user.rb
    doc/examples/user_group/ug_add_user.rb
    doc/examples/user_group/ug_init.rb
    doc/examples/user_group/ug_list.rb


===Initialize a TestSuite database

  # connect the model, creating it if necessary
  model = UserGroupModel.new(GitDS::Database.connect('ug_test.db', true))

===Add a user

  u = model.add_user(username, id, fullname)

===Add a group

  g = model.add_group(username, id, owner_name)

  # add user to group
  u = model.user(username)
  g.add_user(u)

=end

require 'git-ds/database'
require 'git-ds/model'

=begin rdoc
The model has the following structure in the repo:

   user/                          : FsModelItemClass
   user/$NAME/                    : FsModelItem
   user/$NAME/id                  : Property
   user/$NAME/full_name           : Property
   user/$NAME/created             : Property
            
   group/                         : FsModelItemClass
   group/$NAME/                   : FsModelItem
   group/$NAME/id                 : Property
   group/$NAME/owner              : ProxyProperty
   group/$NAME/users              : ProxyItemList
=end

class UserGroupModel < GitDS::Model
  def initialize(db)
    super db, 'user/group model'
  end

=begin rdoc
Add a User to the model.
=end
  def add_user(name, id, fullname='')
    args = {:username => name, :id => id.to_i, :fullname => fullname }
    UserModelItem.new self, UserModelItem.create(self.root, args)
  end

=begin rdoc
Return a list of the usernames of all Users in the model
=end
  def users
    UserModelItem.list(self.root)
  end

=begin rdoc
Instantiate a User object based on the username.
=end
  def user(ident)
    UserModelItem.new self, UserModelItem.instance_path(self.root.path, ident)
  end

=begin rdoc
Add a Group to the model.
=end
  def add_group(name, id, owner_name)
    owner = user(owner_name)

    args = { :name => name, :id => id.to_i, :owner => owner }
    GroupModelItem.new self, GroupModelItem.create(self.root, args)
  end

=begin rdoc
List the names of all Groups in the model.
=end
  def groups
    GroupModelItem.list(self.root)
  end

=begin rdoc
Instantiate a Group object by name.
=end
  def group(ident)
    GroupModelItem.new self, GroupModelItem.instance_path(self.root.path, ident)
  end
end

# ----------------------------------------------------------------------
=begin rdoc
A User. Users consist of a UNIX-style username, an ID number, a full name,
and a timestamp marking when they were created.
=end
class UserModelItem < GitDS::FsModelItem

  name 'user'

  # properties
  property(:id, 0) { |p| p.to_s.to_i == p }
  property(:full_name, '')
  property(:created)

  # Use :username entry in Hash as primary key
  def self.ident_key
    :username
  end

  def self.fill(model, item_path, args)
    super
    properties[:created].set(model, item_path, Time.now.to_s)
  end

=begin rdoc
The name of the user, e.g. 'root'.
=end
  alias :username :ident

=begin rdoc
The ID number of the user, e.g. 1000.
=end
  def id
    integer_property(:id)
  end

  def id=(val)
    set_property(:id, val)
  end

=begin rdoc
The full name of the user, e.g. 'John Q. Public'.
=end
  def full_name
    property(:full_name)
  end

  def full_name=(val)
    set_property(:full_name, val)
  end

=begin rdoc
The timestamp when the user was created.
=end
  def created
    ts_property(:created)
  end

end

# ----------------------------------------------------------------------
=begin rdoc
A group of users. Groups consist of a UNIX-style name, a numeric ID, and
owner (a valid User), and a list of members (valid Users).
=end
class GroupModelItem < GitDS::FsModelItem

  name 'group'

  # properties
  property(:id, 0) { |p| p.to_s.to_i == p }
  link_property(:owner, UserModelItem)

  def initialize(model, path)
    super
    @users = GitDS::ProxyItemList.new(UserModelItem, model, path)
  end

  # Use :name entry in Hash as primary key
  def self.ident_key()
    :name
  end

=begin rdoc
The name of the group, e.g. 'staff'.
=end
  alias :name :ident

=begin rdoc
The ID of the group, e.g. 1000.
=end
  def id
    integer_property(:id)
  end

  def id=(val)
    set_property(:id, val)
  end

=begin rdoc
The owner of the group: a link to a User object.
=end
  def owner
    property(:owner)
  end

  def owner=(u)
    set_property(:owner, u)
  end

=begin rdoc
The names of every User in the group.
=end
  def users
    ensure_valid
    @users.keys
  end

=begin rdoc
Instantiate a User in the group by name.
=end
  def user(name)
    ensure_valid
    @users[name]
  end

=begin rdoc
Add a User to the group. The argument must be a User object.
=end
  def add_user(u)
    ensure_valid
    @users.add(self, u, true)
  end

=begin rdoc
Remove a user from the group, by name.
=end
  def del_user(name)
    ensure_valid
    @users.delete(name)
  end
end
