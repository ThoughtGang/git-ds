#!/usr/bin/env ruby
# Copyright 2011 Thoughtgang <http://www.thoughtgang.org>
# Unit test for Git-DS Index class

require 'test/unit'
require 'fileutils'

require 'git-ds/repo'
require 'git-ds/index'

class TC_GitIndexTest < Test::Unit::TestCase
  TMP = File.dirname(__FILE__) + File::SEPARATOR + 'tmp'

  attr_reader :repo

  def setup
    FileUtils.remove_dir(TMP) if File.exist?(TMP)
    Dir.mkdir(TMP)
    path = TMP + File::SEPARATOR + 'index_test'
    @repo = GitDS::Repo.create(path)
  end

  def teardown
    FileUtils.remove_dir(TMP) if File.exist?(TMP)
  end

  def test_index_add_delete
    name, data = 'test-file-1', '..!!..!!..'

    idx = GitDS::Index.new(@repo)

    # add an item to the index
    idx.add(name, data)

    # list items in index
    sha = idx.write
    t = @repo.git.ruby_git.list_tree(sha)
    assert_equal( 1, t['blob'].keys.count, 
                  'Incorrect Index item count after insert' )
    assert_equal( name, t['blob'].keys.first, 'Incorrect Index item name')

    # remove an item from the index
    idx.delete(name)
    sha = idx.write
    t = @repo.git.ruby_git.list_tree(sha)
    assert_equal( 0, t['blob'].keys.count, 
                 'Incorrect Index item count after delete' )
  end

  def test_index_add_fs
    name, data = 'test/stuff/test-file-fs-1', '-=-=-=-=-='

    idx = GitDS::Index.new(@repo)

    # add an item to the index
    idx.add(name, data, true)
    sha = idx.write
    
    # Verify that item exists in tree
    t = @repo.git.ruby_git.list_tree(sha)
    assert( t['tree'].keys.include?('test'), 
            'Tree does not contain object after index-fs-add' )
    
    # Verify that item exists on disk
    @repo.exec_in_git_dir {
      assert( ::File.exist?(name), 'File not exist after index-fs-add' )
    }

    # verify that deleting removes the file from the FS
    idx.delete(name)
    sha = idx.write
    @repo.exec_in_git_dir {
      assert( (not ::File.exist?(name)), 'File not exist after index-delete' )
    }
  end

  def test_index_add_db
    name, data = 'test/stuff/test-file-db-1', '<><><><><>'

    idx = GitDS::Index.new(@repo)

    # add an item to the index
    idx.add(name, data)
    sha = idx.write

    # Verify that item exists in tree
    t = @repo.git.ruby_git.list_tree(sha)
    assert( t['tree'].keys.include?('test'), 
            'Tree does not contain object after index-db-add' )
    
    # Verify that item does not exist on disk
    @repo.exec_in_git_dir {
      assert( (not ::File.exist? name), 'File exists after index-db-add' )
    }
  end

  def test_staging
    file, data = 'stage-test-1', 'ststststst'
    idx = GitDS::StageIndex.new(@repo)

    # add a file
    idx.add(file, data)
    idx.build

    # Verify that item exists in index
    t = @repo.git.ruby_git.list_tree(idx.sha)
    assert_equal( 1, t['blob'].keys.count, 
                  'Incorrect StageIndex item count after insert' )

    # test sync
    idx.sync
    @repo.exec_in_git_dir {
      lines = `git ls-files --stage`.lines
      item = lines.first.chomp.split(/\s/)[3]
      assert_equal(1, lines.count, 'Staging sync created wrong # of files')
      assert_equal(file, item, 'Staging sync added wrong file to index')
    }
    
    idx = GitDS::StageIndex.read(@repo)
    t = @repo.git.ruby_git.list_tree(idx.sha)
    assert_equal( 1, t['blob'].keys.count, 
                  'Incorrect StageIndex item count after read' )
    
    # insert item with path
    file, data = 'misc/stuff/stage-test-1', 'dfdfdfdf'
    idx.add(file, data)
    idx.build
    t = @repo.git.ruby_git.list_tree(idx.sha)
    assert_equal( 1, t['tree'].keys.count, 
                  'Incorrect StageIndex item count after path-insert' )
    
    # test sync
    idx.sync
    @repo.exec_in_git_dir {
      lines = `git ls-files --stage`.lines
      item = lines.first.chomp.split(/\s/)[3]
      assert_equal(2, lines.count, 'Staging sync created wrong # of files')
      assert_equal(file, item, 'Staging sync added wrong file to index')
    }

    # remove an item from the index
    idx.delete(file)
    sha = idx.write
    t = @repo.git.ruby_git.list_tree(sha)
    assert_equal( 1, t['blob'].keys.count, 
                 'Incorrect StageIndex item count after delete' )
  end

  def test_stage_index_add_fs
    name, data = 'test/stuff/test-stage-file-fs-1', 'vcvcvcvcvc'

    idx = GitDS::StageIndex.new(@repo)

    # add an item to the index
    idx.add(name, data, true)
    sha = idx.write
    
    # Verify that item exists in tree
    t = @repo.git.ruby_git.list_tree(sha)
    assert( t['tree'].keys.include?('test'), 
            'Tree does not contain object after stage-index-fs-add' )
    
    # Verify that item exists on disk
    @repo.exec_in_git_dir {
      assert( ::File.exist?(name), 'File not exist after stage-fs-add' )
    }
  end

  def test_stage_index_add_db
    name, data = 'test/stuff/test-stage-file-db-1', ')()()()()('

    idx = GitDS::StageIndex.new(@repo)

    # add an item to the index
    idx.add(name, data)
    sha = idx.write

    # Verify that item exists in tree
    t = @repo.git.ruby_git.list_tree(sha)
    assert( t['tree'].keys.include?('test'), 
            'Tree does not contain object after stage-index-db-add' )
    
    # Verify that item does not exist on disk
    @repo.exec_in_git_dir {
      assert( (not ::File.exist? name), 'File exists after stage-db-add' )
    }
  end

  def test_stage_commit
    name, data = 'test/stuff/test-stage-commit-1', 'tlctlctlc'

    idx = GitDS::StageIndex.new(@repo)

    # add an item to the index
    idx.add(name, data)
    sha = idx.commit('this is a commit')
    t = @repo.git.ruby_git.list_tree(@repo.commit(sha).tree.id)
    assert_equal( 1, t['tree'].keys.count, 
                 'Incorrect StageIndex item count after commit' )
  end

end

