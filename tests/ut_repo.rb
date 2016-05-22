#!/usr/bin/env ruby
# Copyright 2010 Thoughtgang <http://www.thoughtgang.org>
# Unit test for Git-DS Repo class

require 'test/unit'
require 'fileutils'

require 'git-ds/repo'

class TC_GitRepoTest < Test::Unit::TestCase
  TMP = File.dirname(__FILE__) + File::SEPARATOR + 'tmp'

  attr_reader :repo

  def setup
    FileUtils.remove_dir(TMP) if File.exist?(TMP)
    Dir.mkdir(TMP)

    path = TMP + File::SEPARATOR + 'test'
    @repo = GitDS::Repo.create(path)

    # add basic structure to repo
    idx = @repo.index
    idx.add( 'class a/instance a/prop a', 'aaaaaaaaaa' )
    idx.add( 'class a/instance a/prop b', 'bbbbbbbbbb' )
    idx.add( 'class a/instance b/prop a', 'AAAAAAAAAA' )
    idx.add( 'class a/instance b/prop b', 'BBBBBBBBBB' )
    idx.add( 'class b/instance a/prop a', '1111111111' )
    idx.add( 'class b/instance a/prop b', '2222222222' )
    idx.add( 'class c/instance a/prop a', 'zzzzzzzzzz' )
    idx.add( 'class c/instance a/prop b', 'xxxxxxxxxx' )
    idx.add( 'class c/instance a/class d/prop 1', '-_-_-_-_-_' )
    idx.add( 'class c/instance a/class d/prop 2', '=+=+=+=+=+' )

    idx.commit('initial import')
    @repo.staging = nil
  end

  def teardown
    FileUtils.remove_dir(TMP) if File.exist?(TMP)
  end

  def test_create
    path = TMP + File::SEPARATOR + 'test_create'
    repo = GitDS::Repo.create(path)

    assert(File.exist?(path + File::SEPARATOR + '.git'), 
           "Repo #{path} not created!") 
    assert_equal(path, repo.top_level, 'Repo#top_level returned wrong value')

    repo.exec_in_git_dir {
      assert( File.exist?('.git'), 'Repo#exec_in_git_dir failed' )
    }
    # TODO: repo.exec_git_cmd()
  end

  def test_list
    dir = 'class c/instance a/class d'
    path, data = "#{dir}/prop 1", '-_-_-_-_-_'

    # test include
    assert( @repo.include?(dir), 'Repo#include? does not include path' )
    assert( @repo.include?(path), 'Repo#include? does not include path' )

    assert_nil( @repo.object_data(dir), 'blob data returned for path' )
    assert_equal( data, @repo.path_to_object(path).data, 
                  'Repo#path_to_object#data returned wrong data for blob' )
    assert_equal( data, @repo.object_data(path), 
                  'Repo#object_data returned wrong data for blob' )

    # Test listing of tree contents
    assert_equal( 3, @repo.tree_contents(@repo.tree).keys.count,
                  'Repo#list returns wrong contents for root tree' )
    assert_equal( 3, @repo.tree_contents(@repo.tree(@repo.root_sha)).keys.count,
                  'Repo#list returns wrong contents for root_sha' )
    assert_equal( ['class a', 'class b', 'class c'], @repo.list.keys.sort,
                  'Repo#list returns wrong contents for root' )
    assert_equal( ['instance a', 'instance b'], @repo.list('class a').keys.sort,
                  'Repo#list returns wrong contents for "class a"' )

    # Test listing of only Blobs or only Trees
    assert_equal(0, @repo.list_blobs().count, 'List Blobs has wrong root count')
    assert_equal(3, @repo.list_trees().count, 'List Trees has wrong root count')
    assert_equal(2, @repo.list_blobs('class c/instance a').count, 
                 'List Blobs has wrong count')
    assert_equal(1, @repo.list_trees('class c/instance a').count, 
                 'List Trees has wrong count')

    # Test recursive raw-tree generation
    output = @repo.raw_tree('class c')
    assert_equal(1, output.split("\n").count, 'Incorrect count for raw_tree')
    output = @repo.raw_tree('class c', true)
    assert_equal(4, output.split("\n").count, 'Incorrect count for raw_tree')

    # Make sure that '' gets us a root Tree object
    output = @repo.raw_tree('')
    assert_equal(3, output.split("\n").count, 'Incorrect count for raw_tree')
    output = @repo.raw_tree('', true)
    assert_equal(10, output.split("\n").count, 'Incorrect count for raw_tree')
  end

  def test_index
    idx = @repo.index_new
    assert_equal(GitDS::Index, idx.class, 'Repo#index_new returns wrong class')
    idx = @repo.index
    assert_equal(GitDS::StageIndex, idx.class, 'Repo#index returns wrong class')

    assert( @repo.staging?(), 'Repo#staging returned FALSE' )

    path, data = 'class c/instance a/prop b', 'XXXXXXXXXX'
    @repo.stage { |index|
      index.add( path, data )
    }

    assert_equal(data, @repo.object_data(path), 'Stage did not write data')

    @repo.staging = nil
    assert( (not @repo.staging?), 'Repo#staging returned TRUE' )

    msg = 'this is a test'
    @repo.stage_and_commit(msg) { |index|
      index.add( path, data )
    }

    # ensure this doesn't screw up repo
    output = @repo.raw_tree('')
    assert_equal(3, output.split("\n").count, 'Incorrect count for raw_tree')
  end

  def test_branch_and_tag
    assert_equal(0, @repo.tags.count, 'Expected initial tag count of 0')
    assert_equal('1_2_3_4_5_6_7_8_9_0_', 
                 @repo.clean_tag('1!2@3#4$5%6^7&8*9(0)'),
                 'clean_tag did not clean')

    # Tag a commit
    sha = @repo.commits.first.id
    name = 'the tag is'
    @repo.tag_object(name, sha)
    assert_equal(1, @repo.tags.count, 'Tag did not get added')
    assert_equal('the_tag_is', @repo.tags.first.name, 'Tag name did not match')
    assert_equal(1, 
                 @repo.tags.select{|t| t.name == @repo.clean_tag(name)}.count, 
                 'Tag did not get added with right name')

    assert_equal('0.0.0', @repo.last_branch_tag, 'invalid initial tag value')
    assert_equal('0.0.1', @repo.next_branch_tag, 'next_branch_tag failed')

    assert_equal(GitDS::Repo::DEFAULT_BRANCH, @repo.current_branch,
                 'Current branch is not default branch')
    assert_equal(GitDS::Repo::DEFAULT_BRANCH, @repo.branch.name,
                 'Current branch is not default branch')

    # create new branch
    assert_equal(1, @repo.branches.count, '> 1 branches exist on init')
    new_branch = @repo.create_branch( 'v01' )
    assert_equal(2, @repo.branches.count, 'new branch not added')

    # switch to new branch
    @repo.set_branch(new_branch)
    assert_equal(new_branch, @repo.current_branch, 'Curr branch != new branch')
    assert_equal(new_branch, @repo.branch.name, 'Current branch != new branch')

    # switch back
    @repo.set_branch(GitDS::Repo::DEFAULT_BRANCH)
    assert_equal(GitDS::Repo::DEFAULT_BRANCH, @repo.branch.name,
                 'Current branch is not default branch')

    # create new branch with auto-tag name of 0.0.2
    v2 = @repo.create_branch
    assert_equal('0.0.2', v2, 'New branch did not get assigned 0.0.2 name')
    assert_equal(3, @repo.branches.count, 'new branch not added')

    # switch to new branch and change data
    @repo.set_branch(new_branch)
    assert_equal('v01', @repo.current_branch, 'V01 is not current branch')
    path, data = 'class c/instance a/prop b', '~~~~~~~~~~'
    @repo.stage_and_commit('test commit for merge') { |idx|
      idx.add( path, data )
    }
    assert_equal(data, @repo.object_data(path), 'Stage did not write data')

    # test that staging index gets preserved
    b_stage = @repo.staging
    @repo.set_branch(GitDS::Repo::DEFAULT_BRANCH)
    assert( (not @repo.staging?), 'Staging index not cleared on branch' )
    @repo.set_branch(new_branch)
    assert( (@repo.staging?), 'Staging index not restored on branch' )
    assert_equal(b_stage, @repo.staging, 'Staging index not saved on branch')

    # merge new branch to master
    @repo.merge_branch
    assert_equal(GitDS::Repo::DEFAULT_BRANCH, @repo.branch.name,
                 'Current branch is not default branch')
    assert_equal(data, @repo.object_data(path), 'Merge did not write data')
  end

  def test_index_mod_and_list
    path, data = 'class e/prop_1', '.:.:.:.:.'

    # list top-level should have 3 entries
    assert_equal( 3, @repo.tree_contents(@repo.tree).keys.count,
                  'Repo#list returns wrong contents for root tree' )

    @repo.add( path, data )
    assert_equal( data, @repo.object_data(path), 
                  'Repo#object_data returned wrong data for blob' )

    # list top-level should have 4 entries
    assert_equal( 4, @repo.tree_contents(@repo.tree).keys.count,
                  'Repo#list returns wrong contents for root tree' )

    # Discard staging index
    @repo.unstage

    # list top-level should have 3 entries again
    assert_equal( 3, @repo.tree_contents(@repo.tree).keys.count,
                  'Repo#list returns wrong contents for root tree' )

    @repo.add( path, data )
    assert_equal( data, @repo.object_data(path), 
                  'Repo#object_data returned wrong data for blob' )

    @repo.delete('class e/')
    
    # list top-level should have 3 entries again
    assert_equal( 3, @repo.tree_contents(@repo.tree).keys.count,
                  'Repo#list returns wrong contents for root tree' )
    @repo.staging=nil

    # TODO: modification while index is active.
  end

  def test_add_fs
    path, data = 'test-fs', 'trtrtrtrt'
    @repo.add(path, data, true)
    assert_equal( 4, @repo.tree_contents(@repo.tree).keys.count,
                  'Repo#list returns wrong contents for root tree' )

    @repo.exec_in_git_dir {
      assert( ::File.exist?(path), 'File not exist after repo-fs-add' )
    }

    @repo.unstage
  end

  def test_add_db
    path, data = 'test-db', 'bdbdbdbdb'
    @repo.add(path, data)
    assert_equal( 4, @repo.tree_contents(@repo.tree).keys.count,
                  'Repo#list returns wrong contents for root tree' )

    @repo.exec_in_git_dir {
      assert( (not ::File.exist? path), 'File exists after repo-db-add' )
    }

    @repo.unstage
  end

end

