#!/usr/bin/env ruby
# :title: Git-DS::Database
=begin rdoc

Copyright 2011 Thoughtgang <http://www.thoughtgang.org>
=end

require 'fileutils'

require 'git-ds/repo'
require 'git-ds/config'
require 'git-ds/model'
require 'git-ds/shared'
require 'git-ds/exec_cmd'
require 'git-ds/transaction'

module GitDS

=begin rdoc
Exception raised when a closed database is accessed
=end
  class InvalidDbError < RuntimeError
  end

=begin rdoc
Actually DbConnection to the repository.

Note: all operations should be in exec or transaction blocks. These use a
persistent staging index, and are more efficient.
=end
  class Database < Repo

=begin rdoc
Flag to mark if database has been closed (i.e. connection is invalid).
=end
    attr_reader :stale

=begin rdoc
Actor to use when performing Database operations. All Transaction and
ExecCmd objects will use this actor by default.

Default is nil (i.e. let Git read actor from .git/config or ENV).
=end
    attr_accessor :actor

=begin rdoc
Subcribers that are notified when the model is changed. This is a Hash of
an ident (e.g. a classname, UUID, or symbol) to a 2-element array:
a callback method  and an (optional) object to pass with that method.
=end
    attr_reader :subscribers

=begin rdoc
Return a connection to the Git DB.
Creates the DB if it does not already exist.
=end
    def initialize(path, username=nil, email=nil)
      @stale = true         # DB is always stale until it is initialized

      init = false
      if not File.exist? path
        Repo.create(path)
        init = true
      end

      super(path)
      @stale = false        # DB is connected!

      if init
        # initial commit is needed for branches to work smoothly
        stage { |idx| idx.add('.git-ds/version', "1.0\n") }
        staging.commit('Database initialized.')
        unstage
      end

      @actor = Grit::Actor.new(username, email) if username
      @subscribers = {}

    end

=begin rdoc
Open a connection to database.

If 'create' is true (the default), a database will be created if one does
not exist at 'path'.
=end
    def self.connect(path, create=true)
      return nil if (not create) && (not File.exist? path)
      connect_as(path, nil, nil, create)
    end

=begin rdoc
Connect to a git database as the specified user.
=end
    def self.connect_as(path, username, email, create=true)
      return nil if (not create) && (not File.exist? path)
      new(path, username, email)
    end

=begin rdoc
Close DB connection, writing all changes to disk.

NOTE: This does not create a commit! Ony the staging index changes.
=end
    def close(save=true)
      raise InvalidDbError if @stale

      if save && staging?
        self.staging.write
      end
      unstage
      @stale = true

      # TODO: remove all locks etc
    end

=begin rdoc
Return true if the database is valid (i.e. open)
=end
    def valid?
      @stale == false
    end

    alias :connected? :valid?

=begin rdoc
Delete Database (including entire repository) from disk.
=end
    def purge
      raise InvalidDbError if @stale

      close(false)
      FileUtils.remove_dir(@path) if ::File.exist?(@path)
    end

=begin rdoc
Grit::Repo#config is wrapped by Database#config.
=end
    alias :repo_config :config

=begin rdoc
Provides access to the Hash of Git-DS config variables.
=end
    def config
      @git_config ||= RepoConfig.new(self, 'git-ds')
    end

=begin rdoc
Set the Git author information for the database connection. Wrapper for
actor=.
=end
    def set_author(name, email=nil)
      self.actor = name ? Grit::Actor.new(name, (email ? email : '')) : nil
    end

    # ----------------------------------------------------------------------
=begin rdoc
Subscribe to change notifications from the model. The provided callback will
be invoked whenever the model is modified (specifically, when an outer
Transaction or ExecCmd is completed).

A subscriber can use either block or argument syntax:

  def func_cb(arg)
    ...
  end
  model.subscribe( self.ident, arg, func_cb )

  # block callback
  model.subscribe( self.ident ) { ... }

  # block callback where arg is specified in advance
  model.subscribe( self.ident, arg ) { |arg| ... }
=end
    def subscribe(ident, obj=nil, func=nil, &block)
      cb = (block_given?) ? block : func
      @subscribers[ident] = [cb, obj]
    end

=begin rdoc
Notify all subscribers that a change has occurred.
=end
    def notify
      @subscribers.each { |ident, (block,obj)| block.call(obj) }
    end

=begin rdoc
Unsubscribe from change notification.
=end
    def unsubscribe(ident)
      @subscribers.delete(ident)
    end

    # ----------------------------------------------------------------------
=begin rdoc
Execute a block in the context of the staging index.

See ExecCmd.
=end
    def exec(&block)
      raise InvalidDbError if @stale

      return exec_in_staging(true, &block) if self.staging?

      begin
        self.staging
        exec_in_staging(false, &block)
        self.staging.write
      ensure
        self.unstage
      end

    end

=begin
Execute a transaction in the context of the staging index.

See Transaction.
=end
    def transaction(&block)
      raise InvalidDbError if @stale

      return transaction_in_staging(true, &block) if self.staging?

      begin
        transaction_in_staging(false, &block)
      ensure
        self.unstage
      end
    end

    # ----------------------------------------------------------------------
=begin rdoc
Add files to the database. Calls exec to ensure that a write is not performed
if a staging index already exists.
=end
    def add(path, data='', on_fs=false)
      exec { index.add(path, data, on_fs) }
    end

=begin rdoc
Add files to the database *without* using ExecCmd or Transaction. Care must
be taken in using this as it does not sync/build the staging index, so it must 
be wrapped in an ExecCmd or Transaction, or the index must be synced/built 
after all of the fast_add calls are complete.

See Database#add.
=end
    def fast_add(path, data='', on_fs=false)
      # TODO: verify that this will suffice
      index.add(path, data, on_fs)
    end

=begin rdoc
Delete an object from the database.
=end
    def delete(path)
      exec { index.delete(path) }
    end

=begin rdoc
Wrapper for Grit::Repo#index that checks if Database has been closed.
=end
    def index_new
      raise InvalidDbError if @stale
      super
    end

=begin rdoc
Wrapper for Grit::Repo#staging that checks if Database has been closed.
=end
    def staging
      raise InvalidDbError if @stale
      super
    end

=begin rdoc
Wrapper for Grit::Repo#head that checks if Database has been closed.
=end
    def head
      raise InvalidDbError if @stale
      super
    end

=begin rdoc
Wrapper for Grit::Repo#tree that checks if Database has been closed.
=end
    def tree(treeish = 'master', paths = [])
      raise InvalidDbError if @stale
      super
    end

=begin rdoc
Generate a tag object for the most recent commit.
=end
    def mark(msg)
      tag_object(msg, commits.last.id)
    end

=begin rdoc
Branch-and-merge:
Run block in a transaction under a new branch. If the transaction succeeds,
the branch is merged back into master.

See Database#transaction .
=end
    def branch_and_merge(name=next_branch_tag(), actor=nil, &block)
      raise InvalidDbError if @stale

      # Force a commit before the merge
      # TODO: determine if this is really necessary
      staging.sync
      staging.commit('auto-commit before branch-and-merge', self.actor)

      # ensure staging index is nil [in case branch name was re-used]
      unstage

      # save old actor
      old_actor = self.actor
      self.actor = actor if actor

      sha = commits.last ? commits.last.id : nil
      tag = create_branch(name, sha)
      set_branch(tag, self.actor)

      # execute block in a transaction
      rv = true
      begin
        transaction(&block)
        merge_branch(tag, self.actor)
      rescue Exception =>e
        rv = false
      end

      # restore actor
      self.actor = old_actor if actor

      rv
    end

=begin rdoc
Execute a block using an in-memory Staging index.

This is an optimization. It writes the current index to the git staging index
on disk, replaces it with an in-memory index that DOES NOT write to the object
tree on disk, invokes the block, writes the in-memory index to the git staging
index on disk, then reads the staging index into the repo/database and makes
it the current index.

The idea is to reduce disk writes caused by exec and transaction, which can
end up being very costly when nested.

NOTE: branch-and-merge will fail if in batch mode (TODO: FIX).
=end
    def batch(&block)
      # NOTE: the use of 'self.staging' is quite important in this method.

      # write current index to git-staging-index
      idx = self.staging? ? self.staging : nil
      idx.sync if idx

      # replace current index with an in-mem staging index
      unstage
      self.staging=StageMemIndex.read(self)

      begin
        yield staging if block_given?

      rescue Exception => e
        # ensure index is discarded if there is a problem
        unstage
        self.staging if idx
        raise e
      end

      # write in-mem staging index to git-staging-index
      self.staging.force_sync

      # read git-staging-index if appropriate
      unstage
      self.staging if idx
    end

    # ----------------------------------------------------------------------
    private

=begin rdoc
Execute code block in context of current DB index
=end
    def exec_in_staging(nested, &block)
      cmd = ExecCmd.new(self.staging, nested, &block)
      cmd.actor = self.actor
      cmd.perform
    end

=begin rdoc
Perform transaction in context of current DB index
=end
    def transaction_in_staging(nested, &block)
      t = Transaction.new(self.staging, nested, &block)
      t.actor = self.actor
      t.perform
    end

  end
end
