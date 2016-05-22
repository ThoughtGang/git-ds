#!/usr/bin/env ruby
# :title: Git-DS::Index
=begin rdoc
Wrapper for Grit::Index

Copyright 2010 Thoughtgang <http://www.thoughtgang.org>
=end

require 'rubygems'
require 'grit'
require 'fileutils'

require 'git-ds/shared'

module GitDS

# =============================================================================
=begin rdoc
A Git Index.
=end
  class Index < Grit::Index

=begin rdoc
Write index to the object db, then read the object DB into the GIT staging
index. Returns SHA of new tree.
=end
    def write
      sha = local_write_tree(self.tree, self.current_tree)
      sha
    end

=begin rdoc
Re-implemented from Grit. Grit adds a trailing / to directory names, which
makes it impossible to delete Tree objects!
=end
    def local_write_tree(tree, now_tree=nil)
      tree_contents = {}
      now_tree.contents.each do |obj|
        sha = [obj.id].pack("H*")
        k = obj.name
        tree_contents[k] = "%s %s\0%s" % [obj.mode.to_i.to_s, obj.name, sha]
      end if now_tree

      tree.each do |k, v|
        case v
          when String
            sha = write_blob(v)
            sha = [sha].pack("H*")
            str = "%s %s\0%s" % ['100644', k, sha]
            tree_contents[k] = str
          when Hash
            ctree = now_tree/k if now_tree
            sha = local_write_tree(v, ctree)
            sha = [sha].pack("H*")
            str = "%s %s\0%s" % ['40000', k, sha]
            tree_contents[k] = str
          when false
            tree_contents.delete(k)
        end
      end

      tr = tree_contents.sort.map { |k, v| v }.join('')
      self.repo.git.put_raw_object(tr, 'tree')
    end

=begin rdoc
Add a DB entry at the virtual path 'path' with contents 'contents'
=end
    alias :add_db :add

    def add(path, data, on_fs=false)
      super(path, data)
      add_fs_item(path, data) if on_fs
    end

=begin rdoc
Convenience function to add an on-filesystem object.
=end
    def add_fs(path, data)
      add(path, data, true)
    end

=begin rdoc
Wrapper for Grit::Index#delete that removes the file if it exists on the
filesystem.
=end
    def delete(path)
      super
      @repo.exec_in_git_dir {
        ::FileUtils.remove_entry(path) if ::File.exist?(path)
      }
    end

=begin rdoc
Return true if index includes path.
=end
    def include?(path)
      path_to_object(path) ? true : false
    end

=begin rdoc
Return the data for the object at 'path'. This is required in order for
in-memory indexes to work properly.
=end
    def path_to_object(path)
      # Note: this algorithm is re-implemented from Grit::Index#add
      arr = path.split('/')
      fname = arr.pop
      curr = self.tree
      arr.each do |dir|
        curr = curr[dir] if curr
      end

      #TODO: it would be nice to return a Grit::Blob or Grit::Tree here.
      (curr && fname && curr[fname]) ? curr[fname] : nil
    end

    private

=begin rdoc
Add a DB entry at the filesystem path 'path' with contents 'contents'
=end
    def add_fs_item( path, data )
      fs_path = @repo.top_level + ::File::SEPARATOR + path
      make_parent_dirs(fs_path)

      # Create file in filesystem
      @repo.exec_in_git_dir { ::File.open(fs_path, 'w') {|f| f.write(data)} }
    end

=begin rdoc
Add parent directories as-needed to create 'path' on the filesystem.
=end
    def make_parent_dirs(path)
      tmp_path = ''

      ::File.dirname(path).split(::File::SEPARATOR).each do |dir|
        next if dir.empty?
        tmp_path << ::File::SEPARATOR << dir
        Dir.mkdir(tmp_path) if not ::File.exist?(tmp_path)
      end
    end

  end

=begin rdoc
Index object for the Git staging index.
=end
  class StageIndex < Index

    attr_reader :sha
    attr_reader :parent_commit

=begin rdoc
=end
    def initialize(repo, treeish=nil)
      super(repo)
      @parent_commit = repo.commits(repo.current_branch, 1).first
      treeish = (@parent_commit ? @parent_commit.tree.id : 'master') if \
                not treeish
      read_tree(treeish)
      @sha = self.current_tree.id
    end

=begin rdoc
=end
    def commit(msg, author=nil)
      parents = @parent_commit ? [@parent_commit] : []
      # TODO : why does last_tree cause some commits to fail?
      #          test_transaction(TC_GitDatabaseTest)
      #          transaction commit has wrong message.
      #          <"SUCCESS"> expected but was <"auto-commit on transaction">
      #        Possible bug in Grit::last_tree?
      #last_tree = @parent_commit ? @parent_commit.tree.id : nil
      #sha = super(msg, parents, author, last_tree, @repo.current_branch)
      sha = super(msg, parents, author, nil, @repo.current_branch)
      if sha
        # set index parent_commit to the new commit
        @parent_commit = @repo.commit(sha)
        # read tree back into index
        read_tree(@parent_commit.tree.id)
        sync
      end
      sha
    end

=begin rdoc
Write tree object for index to object database.
=end
    def write
      @sha = super
    end

=begin rdoc
Write, read tree. Done when a tree is requested.
=end
    def build
      return @sha if self.tree.empty?
      self.read_tree(self.write)
    end

    def read_tree(sha)
      super
    end

=begin rdoc
Sync with staging index. This causes the Git index (used by command-line tools)
to be filled with the contents of this index.

This can be instead of a commit to ensure that command-line tools can access
the index contents.
=end
    def sync
      self.build
      @repo.exec_in_git_dir { `git read-tree #{@sha}` }
    end

    alias :force_sync :sync

=begin rdoc
Read staging index from disk and create a StagingIndex object for it.

This can be used to access index contents created by command-line tools.
=end
    def self.read(repo)
      sha = repo.exec_in_git_dir{`git write-tree`}.chomp
      new(repo, sha)
    end

  end

=begin rdoc
In-memory staging index.

This replaces the StageIndex#build method with a nop, so that the index is
not written to disk.

This is primarily useful in transactions or in methods such as Database#batch.
Keepin the tree in-memory as long as necessary reduces disk writes and
speeds up bulk insert/delete operations.
=end
  class StageMemIndex < StageIndex

=begin rdoc
Return the sha of the stage index on disk. This DOES NOT synchronize the
in-memory index with the on-disk index.
=end
    def build
      return @sha
    end

=begin rdoc
Replace standard sync with a no-op.
=end
    def sync
    end

=begin rdoc
Force a sync-to-disk. This is used by batch mode to ensure a sync.
=end
    def force_sync
      self.read_tree(self.write)
      @repo.exec_in_git_dir { `git read-tree #{@sha}` }
    end
  end


end

