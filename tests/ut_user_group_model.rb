#!/usr/bin/env ruby
# Copyright 2011 Thoughtgang <http://www.thoughtgang.org>
# Unit test for Git-DS Model class API

require 'test/unit'
require 'fileutils'

require 'git-ds/database'
require 'git-ds/model'

# =============================================================================
# Test database model:
#   user/                          : FsModelItemClass
#   user/$NAME/                    : FsModelItem
#   user/$NAME/id                  : Property
#   user/$NAME/role/               : DbModelItemClass
#   user/$NAME/role/$NAME/         : DbModelItem
#   user/$NAME/role/$NAME/auth     : Property
#            
#   group/                         : FsModelItemClass
#   group/$NAME/                   : FsModelItem
#   group/$NAME/id                 : Property

# ----------------------------------------------------------------------
# User Role. This is an in-DB item.
class UserRoleModelItem
  include GitDS::DbModelItemObject
  extend GitDS::DbModelItemClass

  name 'role'

  property(:auth, 127) { |p| p.to_s.to_i == p && p >= 0 && p < 1024 }

  def initialize(model, path)
    initialize_item(model, path)
  end

  def auth
    integer_property(:auth)
  end

  def auth=(val)
    set_property(:auth, val)
  end
end

# ----------------------------------------------------------------------
class UserModelItem
  include GitDS::FsModelItemObject
  extend GitDS::FsModelItemClass

  name 'user'

  # properties
  property(:id, 0) { |p| p.to_s.to_i == p }


  def initialize(model, path)
    initialize_item(model, path)
    @roles = GitDS::ModelItemList.new(UserRoleModelItem, model, path)
  end

  # Use :username entry in Hash as primary key
  def self.ident_key
    :username
  end

  # Override default fill method to set non-Property children
  def self.fill(model, item_path, args)
    super

    # create user role
    args[:roles].each do |role|
      UserRoleModelItem.create_in_path(model, item_path, role)
    end
  end

  alias :username :ident

  def id
    integer_property(:id)
  end

  def id=(val)
    set_property(:id, val)
  end

  def roles
    ensure_valid
    @roles.keys
  end

  def role(name)
    ensure_valid
    @roles[name]
  end

  def add_role(ident, auth)
    @roles.add(self, {:ident => ident, :auth => auth})
  end

end

# ----------------------------------------------------------------------
class GroupModelItem
  include GitDS::FsModelItemObject
  extend GitDS::FsModelItemClass

  name 'group'

  # properties
  property(:id, 0) { |p| p.to_s.to_i == p }
  link_property(:owner, UserModelItem)


  def initialize(model, path)
    initialize_item(model, path)
    @users = GitDS::ProxyItemList.new(UserModelItem, model, path)
  end

  # Use :name entry in Hash as primary key
  # NOTE: This tests overriding of ident() instead of ident_key()
  def self.ident(args)
    args[:name]
  end

  alias :name :ident

  def id
    integer_property(:id)
  end

  def id=(val)
    set_property(:id, val)
  end

  def owner
    get_property(:owner)
  end

  def owner=(u)
    set_property(:owner, u)
  end

  def users
    ensure_valid
    @users.keys
  end

  def user(name)
    ensure_valid
    @users[name]
  end

  def add_user(u)
    @users.add(self, u, true)
  end

  def del_user(name)
    @users.delete(name)
  end
end


# =============================================================================
class TC_GitUserGroupModelTest < Test::Unit::TestCase
  TMP = File.dirname(__FILE__) + File::SEPARATOR + 'tmp'

  attr_reader :db, :model

  def setup
    FileUtils.remove_dir(TMP) if File.exist?(TMP)
    Dir.mkdir(TMP)
    path = TMP + File::SEPARATOR + 'ug_model_test'
    @db = GitDS::Database.new(path)
    @model = GitDS::Model.new(@db)
  end

  def teardown
    FileUtils.remove_dir(TMP) if File.exist?(TMP)
  end

  # ----------------------------------------------------------------------
  def test_user_item
    assert_equal(0, UserModelItem.list(@model.root).count, 'init # Users not 0')

    args = { :username => 'admin', :id => 1, 
             :roles => [ {:ident => 'sysadmin', :auth => 255},
                         {:ident => 'operator'} ]
           }
    path = UserModelItem.create(@model.root, args)
    assert_equal(1, UserModelItem.list(@model.root).count, 'User not created')

    # User should exist on filesystem
    @db.exec_in_git_dir {
      assert(::File.exist?(path), 'UserModelItem.create failed')
    }

    assert( @model.exist?(path), 'User not created in object database' )
    assert_equal(2, @model.list_children(path).count, 'User prop not created')
    assert_equal(1, UserModelItem.list(@model.root).count, '>1 Users exist')

    # Role should exist in database
    role_path = path + File::SEPARATOR + 'role'
    assert_equal(2, @model.list_children(role_path).count)

    auth_path = role_path + File::SEPARATOR + 'sysadmin' + File::SEPARATOR + 
                'auth'
    assert( @model.exist?(auth_path) )

    u = UserModelItem.new(@model, path)
    assert_equal(args[:username], u.ident, 'User ident was not set')
    assert_equal(args[:username], u.username, 'User username was not set')
    assert_equal(args[:id], u.id, 'User property id was not set')
    # try again after cache
    assert_equal(args[:id], u.id, 'User property id was not cached')
    assert_equal(args[:id], u.property_cache[:id], 'Cached property is wrong')

    u.id = 5
    assert_equal(5, u.id, 'User property id was not changed')
    assert_equal(5, u.property_cache[:id], 'User property id was not changed')

    # Verify that role accessor works
    assert_equal(2, u.roles.count, 'Incorrect number of User roles')
    assert_equal(['operator', 'sysadmin'], u.roles, 'Incorrect User roles')
    assert_equal('operator', u.role('operator').ident, 'Incorrect role ident')
    assert_equal(255, u.role('sysadmin').auth, 'Incorrect role auth')

    u.role('operator').auth = 6
    assert_equal(6, u.role('operator').auth, 'Role auth did not get set')

    u.add_role('sucker', 7)
    assert_equal(3, u.roles.count, 'User role did not get added')
    assert_equal(['operator', 'sucker', 'sysadmin'], u.roles, 
                 'Incorrect User roles after add')
    assert_equal(7, u.role('sucker').auth, 'Role auth did not get set on add')

    u.role('sucker').delete
    assert_equal(2, u.roles.count, 'User role did not get deleted')
    assert_equal(['operator', 'sysadmin'], u.roles, 'Incorrect User roles')

    u.delete
    assert( (not @model.exist? path) )
    assert_equal(0, UserModelItem.list(@model.root).count, '>0 Users exist')

    assert_raises(GitDS::InvalidModelItemError, 'Deleted item still usable') {
      u.id
    }
    assert_raises(GitDS::InvalidModelItemError, 'Deleted item still usable') {
      u.username
    }
    assert_raises(GitDS::InvalidModelItemError, 'Deleted item still usable') {
      u.delete
    }
  end

  # ----------------------------------------------------------------------
  def test_group
    assert_equal(0, GroupModelItem.list(@model.root).count, 'init # Groups > 0')

    args = { :name => 'staff', :id => 1000 }
    path = GroupModelItem.create(@model.root, args)
    assert_equal(1, GroupModelItem.list(@model.root).count, 'Group not created')

    # Group should exist on filesystem
    @db.exec_in_git_dir {
      assert(::File.exist?(path), 'GroupModelItem.create failed')
    }

    assert( @model.exist?(path), 'Group not created in object database' )
    assert_equal(1, @model.list_children(path).count, 'Group prop not created')
    assert_equal(1, GroupModelItem.list(@model.root).count, '>1 Groups exist')

    g = GroupModelItem.new(@model, path)

    assert_equal(0, g.users.count, 'User count > 0 in new group')

    user_defs = [
      { :username => 'admin', :id => 1, 
        :roles => [{:ident => 'sysadmin', :auth => 255}, {:ident => 'operator'}]
      },
      { :username => 'bob', :id => 2, 
        :roles => [{:ident => 'sysadmin', :auth => 1}, {:ident => 'operator'}]
      },
      { :username => 'bill', :id => 3, 
        :roles => [{:ident => 'sysadmin', :auth => 127}, {:ident => 'operator'}]
      },
      { :username => 'jane', :id => 4, 
        :roles => [{:ident => 'sysadmin', :auth => 15}, {:ident => 'operator'}]
      }
    ]
    user_defs.each do |u| 
      u[:path] = UserModelItem.create(@model.root, u)
      u[:obj] = UserModelItem.new(@model, u[:path])
      g.add_user(u[:obj])
    end

    assert_equal(user_defs.count, g.users.count, 'Bad User count new group')

    assert_equal(user_defs.inject([]){ |arr, u| arr << u[:username] }.sort,
                 g.users, 'Group user list does not match')

    g.del_user('jane')
    assert_equal(user_defs.count - 1, g.users.count, 'User not deleted!')

    # cleanup
    user_defs.each { |u| u[:obj].delete }

    g.delete
    assert( (not @model.exist? path), 'path not deleted!' )
    assert_equal(0, GroupModelItem.list(@model.root).count, '>0 Groups exist')

    assert_raises(GitDS::InvalidModelItemError, 'Deleted item still usable') {
      g.id
    }
    assert_raises(GitDS::InvalidModelItemError, 'Deleted item still usable') {
      g.delete
    }
  end

end

