#!/usr/bin/env ruby
# :title: Git-DS::Repo
=begin rdoc
Grit wrappers.

Copyright 2010 Thoughtgang <http://www.thoughtgang.org>
=end

require 'rubygems'
require 'grit'

require 'git-ds/index'
require 'git-ds/shared'

# TODO: mutex for staging
# TODO: cross-process (file) locking? via config or something. Maybe in Database

module GitDS

=begin rdoc
Error raised when a command-line Git command files.
=end
  class CommandError < RuntimeError
  end

=begin rdoc
A Git repository.

Note: StagingIndex is cached, as it is from the command line.
=end
  class Repo < Grit::Repo
    GIT_DIR = ::File::SEPARATOR + '.git'

    DEFAULT_TAG = '0.0.0'
    attr_reader :last_branch_tag

    DEFAULT_BRANCH='master'
    attr_reader :current_branch

    attr_reader :path

    # TODO: something more intelligent, e.g. with git/repo options
    def self.create(path)
      Grit::Repo.init(path)

      # handle broken Grit init
      if not File.exist?(path + GIT_DIR)
        `git init #{path}`
      end

      self.new(path)          # discard Grit::Repo object and use a Repo object
    end

=begin rdoc
Return the top-level directory of the repo containing the location 'path'.
=end
    def self.top_level(path='.')
      local = (path == '.')
      old_dir = nil

      if path != '.'
        old_dir = Dir.getwd
        dest = (File.directory? path) ? path : File.dirname(path)
        Dir.chdir dest
      end

      dir = `git rev-parse --show-toplevel`.chomp
      Dir.chdir old_dir if old_dir

      (dir == '.git') ? '.' : dir.chomp(GIT_DIR) 
    end

=begin rdoc
Initialize a repo from the .git subdir in the given path.
=end
    def initialize(path)
      path.chomp(GIT_DIR) if path.end_with? GIT_DIR
      @path = (path.empty?) ? '.' : path

      # TODO: get last branch tag from repo
      #       prob as a git-config
      @last_branch_tag = DEFAULT_TAG.dup
      @current_branch = DEFAULT_BRANCH.dup
      @staging_index = nil
      @saved_stages = {}

      super(@path + GIT_DIR)
    end

=begin rdoc
Return the top-level directory of the repo (the parent of .git).
=end
    def top_level
      git.git_dir.chomp(GIT_DIR)
    end

=begin rdoc
Return true if path exists in repo (on fs or in-tree)
=end
    def include?(path)
      path_to_object(path) ? true : false
    end

    alias :exist? :include?

# ----------------------------------------------------------------------
=begin rdoc
Return a cleaned-up version of the tag name, suitable for use as a filename.
Replaces all non-alphanumeric characters (except "-.,") with "_". 
=end
    def clean_tag(name)
      name.gsub( /[^-.,_[:alnum:]]/, '_' )
    end

=begin rdoc
Returns the next value for a tag. This is primarily used to auto-generate
tag names, e.g. 1.0.1, 1.0.2, etc.
=end
    def next_branch_tag
      @last_branch_tag.succ!
    end

=begin rdoc
Return the Head object for the specified branch
=end
    def branch(tag=@current_branch)
      get_head(tag)
    end

=begin rdoc
Creates a branch in refs/heads and associates it with the specified commit.
If sha is nil, the latest commit from 'master' is used.
The canonical name of the tag is returned.
=end
    def create_branch( tag=next_branch_tag(), sha=nil )
      if not sha
        sha = commits.last.id
        #sha = branches.first.commit.id if not sha
      end
      name = clean_tag(tag)
      update_ref(name, sha)
      name
    end

=begin rdoc
Sets the current branch to the specified tag. This changes the default
branch for all repo activity and sets HEAD.
=end
    def set_branch( tag, actor=nil )
      # allow creating of new branches via -b if they do not exist
      opt = (is_head? tag) ? '' : '-b'

      # Save staging index for current branch
      @saved_stages[@current_branch] = self.staging if staging?

      exec_git_cmd( "git checkout -q -m #{opt} '#{tag}'", actor )

      # Synchronize staging index (required before merge)
      unstage

      # Update current_branch info and restore staging for branch
      self.staging = @saved_stages[tag]
      self.staging.sync if staging?
      @current_branch = tag
    end

    alias :branch= :set_branch

=begin rdoc
Merge specified branch into master.
=end
    def merge_branch( tag=@current_branch, actor=nil )
      raise "Invalid branch '#{tag}'" if not is_head?(tag)

      tag.gsub!(/['\\]/, '')

      # switch to master branch
      set_branch(DEFAULT_BRANCH, actor)

      # merge target branch to master branch

      rv = nil
      begin
        rv = exec_git_cmd("git merge -n --no-ff --no-log --no-squash '#{tag}'", 
                          actor)
      rescue CommandError => e
        $stderr.puts e.message
      end
      rv
    end

=begin rdoc
Tag (name) an object, e.g. a commit.
=end
    def tag_object(tag, sha)
      git.fs_write("refs/tags/#{clean_tag(tag)}", sha)
    end

# ----------------------------------------------------------------------

=begin rdoc
Return an empty git index for the repo.
=end
    def index_new
      Index.new(self)
    end

=begin rdoc
Return the staging index for the repo.
=end
    def staging
      # TODO: mutex
      @staging_index ||= StageIndex.read(self)
    end

=begin rdoc
Set the staging index. This can be used to clear the staging index, or to
use a specific index as the staging index.
=end
    def staging=(idx)
      # TODO: mutex
      @staging_index = idx
    end

=begin rdoc
Close staging index.
This discards all (non-committed) changes in the staging index.
=end
    def unstage
      self.staging=(nil)    # yes, the self is required. not sure why.
    end

=begin rdoc
Return true if a staging index is active.
=end
    def staging?
      @staging_index != nil
    end

    alias :index :staging
    alias :index= :staging=
    
=begin rdoc 
Yield staging index to the provided block, then write the index when the
block returns.
This allows the Git staging index to be modified from within Ruby, with all
changes being visible to the Git command-line tools.
Returns staging index for chaining purposes.
=end
    def stage(&block)
      idx = self.staging
      rv = yield idx
      idx.build
      rv
    end

=begin rdoc
Read the Git staging index, then commit it with the provided message and
author info.
Returns SHA of commit.
=end
    def stage_and_commit(msg, actor=nil, &block)
      stage(&block)
      sha = staging.commit(msg, actor)
      unstage
      sha
    end

# ----------------------------------------------------------------------
=begin rdoc
Change to the Repo#top_level dir, yield to block, then pop the dir stack.
=end
    def exec_in_git_dir(&block)
      curr = Dir.getwd
      result = nil
      begin
        Dir.chdir top_level
        result = yield
      rescue
        raise
      ensure
        Dir.chdir curr
      end
      result
    end

=begin rdoc
Execute the specified command using Repo#exec_in_git_dir.
=end
    def exec_git_cmd( cmd, actor=nil )
      old_aname = ENV['GIT_AUTHOR_NAME']
      old_aemail = ENV['GIT_AUTHOR_EMAIL']
      old_cname = ENV['GIT_COMMITTER_NAME']
      old_cemail = ENV['GIT_COMMITTER_EMAIL']
      old_pager = ENV['GIT_PAGER']

      if actor
        ENV['GIT_AUTHOR_NAME'] = actor.name
        ENV['GIT_AUTHOR_EMAIL'] = actor.email
        ENV['GIT_COMMITTER_NAME'] = actor.name
        ENV['GIT_COMMITTER_EMAIL'] = actor.email
      end
      ENV['GIT_PAGER'] = ''

      # Note: we cannot use Grit#raw_git_call as it requires an index file
      rv = exec_in_git_dir do 
        `#{cmd}`
        raise CommandError, rv if $? != 0
      end

      ENV['GIT_AUTHOR_NAME'] = old_aname
      ENV['GIT_AUTHOR_EMAIL'] = old_aemail
      ENV['GIT_COMMITTER_NAME'] = old_cname
      ENV['GIT_COMMITTER_EMAIL'] = old_cemail
      ENV['GIT_PAGER'] = old_pager

      rv
    end

# ----------------------------------------------------------------------
    alias :add_files :add

=begin rdoc
Add a DB entry at the filesystem path 'path' with contents 'data'. If
'on_fs' is true, the file is created in the filesystem as well.
This uses the staging index.
=end
    def add(path, data='', on_fs=false)
      self.stage { |idx| idx.add(path, data, on_fs) }
    end

=begin rdoc
Remove an object from the database. This can be a path to a Tree or a Blob.
=end
    def delete(path)
      self.stage { |idx| idx.delete(path) }
    end

=begin rdoc
Fetch the contents of a DB or FS object from the object database. This uses
the staging index.
Note: This returns nil if path is a Tree instead of a blob
=end
    def object_data(path)
      blob = path_to_object(path)
      return nil if (not blob) || (blob.kind_of? Grit::Tree)
      blob.kind_of?(Grit::Blob) ? blob.data : blob
    end

# ----------------------------------------------------------------------
=begin rdoc
The Tree object for the given treeish reference 
  +treeish+ is the reference (default Repo#current_branch)
  +paths+ is an optional Array of directory paths to restrict the tree (default [])

Uses staging index if present and provides wrapper for nil treeish.

 Examples 
  repo.tree('master', ['lib/'])

 Returns Grit::Tree (baked)
=end
    def tree(treeish=nil, paths = [])
      begin 
        if staging? && (not treeish)
          @staging_index.sync
          super(@staging_index.current_tree.id, paths)
        else
          treeish = @current_branch if not treeish
          super
        end
      rescue Grit::GitRuby::Repository::NoSuchPath
        
      end
    end


=begin rdoc
Return the SHA1 of 'path' in repo. 
Uses staging index if present.
=end
    def path_to_sha(path, head=@current_branch)
      # Return the root of the repo if no path is specified
      return root_sha(head) if (not path) || (path.empty?)

      if staging?
        @staging_index.sync
        head = @staging_index.current_tree.id
      end

      dir = tree(head, [path])
      (dir && dir.contents.length > 0) ? dir.contents.first.id : nil
    end

=begin rdoc
Return the SHA of the root Tree in the repository.

Uses the staging index if it is active.
=end
    def root_sha(head=@current_branch)
      if staging?
        @staging_index.sync
        return @staging_index.sha
      end

      (self.commits.count > 0) ? self.commits.last.tree.id : nil
    end

=begin rdoc
Return a Hash of the contents of 'tree'. The key is the filename, the 
value is the Grit object (a Tree or a Blob).
=end
    def tree_contents(tree)
      return {} if not tree
      tree.contents.inject({}) { |h,item| h[item.name] = item; h }
    end

=begin rdoc
Return a Hash of the contents of 'path'. This is just a wrapper for 
tree_contents.
=end
    def list(path=nil)
      sha = path_to_sha(path)
      # ensure correct operation even if path doesn't exist in repo
      t = sha ? tree(sha) : tree(@current_branch, (path ? [path] : []))
      t ? tree_contents( t ) : {}
    end

=begin rdoc
Return Hash of all Blob child objects at 'path'.
=end
    def list_blobs(path='')
      list(path).delete_if { |k,v| not v.kind_of?(Grit::Blob) }
    end

=begin rdoc
Return Hash of all Tree child objects at 'path'.
=end
    def list_trees(path='')
      list(path).delete_if { |k,v| not v.kind_of?(Grit::Tree) }
    end

=begin rdoc
Returns the raw (git cat-file) representation of a tree.
=end
    def raw_tree(path, recursive=false)
      # Note: to construct recursive tree: 
      #   Tree.allocate.construct_initialize(repo, treeish, output)
      #   from repo.git.ls_tree or raw_tree
      sha = path_to_sha(path)
      sha ? git.ruby_git.get_raw_tree( sha, recursive ) : ''
    end

=begin rdoc
Fetch an object from the repo based on its path.

If a staging index exists, its tree will be used; otherwise, the tree
Repo#current_branch will be used.

The object returned will be a Grit::Blob, a Grit::Tree, or the raw data from
the staging index.
=end
    def path_to_object(path)
      treeish = (@staging_index ? staging.sha : @current_branch)
      tree = self.tree(treeish, [path])
      return tree.blobs.first if tree && (not tree.blobs.empty?)
      return tree.trees.first if tree && (not tree.trees.empty?)

      # check staging index in case object has not been written to object DB
      staging? ? staging.path_to_object(path) : nil
    end

  end

end
