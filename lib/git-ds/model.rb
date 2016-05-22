#!/usr/bin/env ruby
# :title: Git-DS::Model
=begin rdoc

Copyright 2010 Thoughtgang <http://www.thoughtgang.org>
=end

require 'git-ds/shared'
require 'git-ds/config'
require 'git-ds/model/property'
require 'git-ds/model/item'
require 'git-ds/model/db_item'
require 'git-ds/model/fs_item'
require 'git-ds/model/item_list'
require 'git-ds/model/item_proxy'
require 'git-ds/model/root'

# TODO: REFACTOR to act as delegate for database

# TODO: register ModelItemClass name, e.g. 'user', with model.
#       then to instantiate, get item name from path, e.g.
#       system/1/user/1 would be 'user'
#       ...and use that to determine class to instantiate.
# TODO: query/find/grep (search of object contents or paths)

module GitDS

=begin rdoc
Instance methods used by a Model object.

Note: This is an instance-method module. It should be included, not extended.
=end
  module ModelObject

=begin rdoc
The Root item for the Model. 
=end
    attr_reader :root

=begin rdoc
The database connection for the model. This is expected to be a GitDS::Database
object.
=end
    attr_reader :db

=begin rdoc
The name of the model. This is only used for storing configuration variables.
=end
    attr_reader :name

    def initialize_model(db, name='generic', root=nil)
      @db = db
      @root = root ? root : RootItem.new(self)
      @name = name
    end

=begin rdoc
Provides access to the Hash of Model-specific config variables.
=end
    def config
      @git_config ||= RepoConfig.new(@db, 'model-' + @name)
    end

=begin rdoc
Returns true if Model contains path.
=end
    def include?(path)
      @db.include? path
    end

    alias :exist? :include?

=begin rdoc
List children (filenames) of path. Returns [] if path is not a directory.
=end
    def list_children(path=root.path)
      @db.list(path).keys.sort
    end

=begin rdoc
Add an item to the object DB.
=end
    # Might be better as add child?
    def add_item(path, data)
      # note: @db.add uses exec {} so there is no need to here.
      @db.add(path, data)
    end

=begin rdoc
Add an item to the object DB and the filesystem.
=end
    def add_fs_item(path, data)
      # note: @db.add uses exec {} so there is no need to here.
      @db.add(path, data, true)
    end

=begin rdoc
Return the contents of the BLOB at path.
=end
    def get_item(path)
      @db.object_data(path)
    end

=begin rdoc
Delete an item from the object DB (and the filesystem, if it exists).
=end
    def delete_item(path)
      # note: @db.delete uses exec {} so there is no need to here.
      @db.delete(path)
    end

=begin rdoc
Execute block as a database ExecCmd.
=end
    def exec(&block)
      @db.exec(&block)
    end

=begin rdoc
Execute block as a database transaction.
=end
    def transaction(&block)
      @db.transaction(&block)
    end

=begin rdoc
Execute a transaction in a branch, then merge if it was successful.

See Database#branch_and_merge.
=end
    def branched_transaction(name=@db.next_branch_tag(), &block)
      raise 'Branched transactions cannot be nested' if @db.staging?
      @db.branch_and_merge(name, &block)
    end 

=begin
Execute a block using an in-memory Staging index.

This isjust a wrapper for Database#batch.
=end
    def batch(&block)
      @db.batch(&block)
    end

  end

=begin rdoc
A data model.
=end
  class Model
    include ModelObject

    def initialize(db, name='generic', root=nil)
      initialize_model(db, name, root)
    end
  end

end
