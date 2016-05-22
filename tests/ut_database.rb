#!/usr/bin/env ruby
# Copyright 2010 Thoughtgang <http://www.thoughtgang.org>
# Unit test for Git-DS Database class

require 'test/unit'
require 'fileutils'

require 'git-ds/database'

# StageIndex that tracks the number of writes made
class TestStageIndex < GitDS::StageIndex
  attr_reader :write_count

  def commit(msg, author=nil)
    @write_count ||= 0
    @write_count += 1
    super
  end

  def clear_write_count
    @write_count = 0
  end
end

class TC_GitDatabaseTest < Test::Unit::TestCase
  TMP = File.dirname(__FILE__) + File::SEPARATOR + 'tmp'

  attr_reader :db

  def setup
    FileUtils.remove_dir(TMP) if File.exist?(TMP)
    Dir.mkdir(TMP)

    path = TMP + File::SEPARATOR + 'db_test'
    @db = GitDS::Database.new(path)
  end

  def teardown
    FileUtils.remove_dir(TMP) if File.exist?(TMP)
  end

  def test_connect
    path = TMP + File::SEPARATOR + 'test-db-conn'

    # no-create should refuse to create the database
    GitDS::Database.connect(path, false)
    assert( (not File.exist?(path + File::SEPARATOR + '.git')), 
            "Repo #{path} incorrectly created by connect" ) 

    # ...otherwise connect should create the db
    db = GitDS::Database.connect(path)
    assert( File.exist?(path + File::SEPARATOR + '.git'), 
            "Repo #{path} not created by connect" ) 

    # verify that closing the DB works.
    db.close

    # verify that a closed database cannot be acted on
    # NOTE: this should verify every method 
    assert_raise( GitDS::InvalidDbError ) { db.exec }
    assert_raise( GitDS::InvalidDbError ) { db.head }
    assert_raise( GitDS::InvalidDbError ) { db.tree }
    assert_raise( GitDS::InvalidDbError ) { db.index }
    assert_raise( GitDS::InvalidDbError ) { db.transaction }
    assert_raise( GitDS::InvalidDbError ) { db.purge }
    assert_raise( GitDS::InvalidDbError ) { db.close }
  end

  def test_create_delete
    path = TMP + File::SEPARATOR + 'test-db'

    # test that ctor creates a database by default
    GitDS::Database.new(path)
    assert( File.exist?(path + File::SEPARATOR + '.git'), 
            "Repo #{path} not created via new" )

    # test that connecting to an existing database works
    db = GitDS::Database.connect(path, false)
    assert_not_nil( db, 'Connect to existing DB failed' )

    # test that deleting a database works
    db.purge
    assert( (not File.exist?(path + File::SEPARATOR + '.git')),
            "Repo #{path} did not get deleted" )
  end

  def test_config
    cfg = GitDS::RepoConfig.new(@db)
    assert_equal('misc.stuff', cfg.path('stuff'), 'Default path is wrong')

    cfg = GitDS::RepoConfig.new(@db, 'a_b c?d')
    assert_equal('a-b-c-d.stuff', cfg.path('stuff'), 'Cleaned path is wrong')

    cfg = GitDS::RepoConfig.new(@db, 'test')
    cfg['stuff'] = '123456'
    assert_equal('123456', cfg['stuff'], 'Could not write to section')

    assert_equal('', @db.config['a test entry'], 'Test cfg entry not empty')
    assert_equal('git-ds.a-test-entry', @db.config.path('a test entry'), 
                 'Config object generated wrong path')
    @db.config['a test entry'] = 'abcdef'
    assert_equal('abcdef', @db.config['a test entry'], 'Cfg string incorrect')
  end

  def test_staging
    assert((not @db.staging?), 'db.staging not nil by default')

    index = GitDS::StageIndex.new(@db)
    @db.staging = index
    assert_equal(index, @db.staging, 'db.staging= method failed')

    @db.staging = nil
    assert((not @db.staging?), 'db.staging=nil method failed')
  end

  def test_exec
    assert((not @db.staging?), 'db.staging not nil by default')

    # test with no index
    fname, data = 'a_test_file', '123456'
    @db.exec { index.add(fname, data)  }
    assert( (not @db.staging?), 'exec created current index!')

    # verify that exceptions do not break anything
    assert_raises(RuntimeError, 'ExecCmd did not propagate error') {
      @db.exec {
        raise RuntimeError
      }
    }

    # Verify that the exec worked
    index = TestStageIndex.new(@db)
    blob = index.current_tree./(fname)
    assert_not_nil(blob, "db.exec did not create '#{fname}' in staging")
    assert_equal(data, blob.data, "BLOB data for '#{fname}' does not match")

    # test exec with staging set
    @db.staging = index
    @db.exec { index.delete(fname) }
    index.build
    blob = index.current_tree./(fname)
    assert_equal(index, @db.staging, 'db.exec clobbered staging')
    assert_nil(blob, "db.exec did not delete '#{fname}' in staging")

    # test nested exec
    name1, data1 = 'test1', '!!##$$@@^^**&&%%'
    name2, data2 = 'test2', '_-_-_-'
    @db.staging.clear_write_count
    @db.exec {
      index.add(name1, data1)
      database.exec { index.add(name2, data2) }
    }
    @db.staging.commit('etc')
    assert_equal(index, @db.staging, 
                 'nested db.exec clobbered staging')
    assert_equal(1, @db.staging.write_count, 
                 'Nested exec caused > 1 write!')

    # verify that both files in nested exec were created
    blob = index.current_tree./(name1)
    assert_not_nil(blob, "nested db.exec did not create '#{name1}' in staging")
    assert_equal(data1, blob.data, "BLOB data for '#{name1}' does not match")

    blob = index.current_tree./(name2)
    assert_not_nil(blob, "nested db.exec did not create '#{name2}' in staging")
    assert_equal(data2, blob.data, "BLOB data for '#{name2}' does not match")

    # cleanup
    index.delete(name1)
    index.delete(name2)
    @db.staging = nil

    # test commits
    num_commits = @db.commits.count
    @db.exec { 
      index.add('exec-nested-commit-file-1', 'zaazza') 
      database.exec {
        index.add('exec-nested-commit-file-2', 'plplpl')
        commit
      }
    }
    assert_equal(num_commits + 2, @db.commits.count, 'Nested commits failed')
  end

  def test_transaction
    assert((not @db.staging?), 'db.staging not nil by default')

    # test with no index
    fname, data = 'test_file_1', 'abcdef'
    @db.transaction { index.add(fname, data)  }
    assert( (not @db.staging?), 'transaction created current index!')

    # Verify that the transaction worked
    index = TestStageIndex.new(@db)
    blob = index.current_tree./(fname)
    assert_not_nil(blob, "db.exec did not create '#{fname}' in staging")
    assert_equal(data, blob.data, "BLOB data for '#{fname}' does not match")
    
    # test rollback method
    name1, data1 = 'test_file_2', '54321'
    @db.transaction {
      index.add(name1, data1)
      rollback
    }
    blob = index.current_tree./(name1)
    assert_nil(blob, "rollback still created '#{name1}' in staging")

    # test nested rollback
    @db.transaction {
      index.add(name1, data1)
      database.transaction { rollback }
    }
    blob = index.current_tree./(name1)
    assert_nil(blob, "rollback still created '#{name1}' in staging")
    
    # test rollback on raise
    @db.transaction {
      propagate
      index.add(name1, data1)
      rollback
    }
    blob = index.current_tree./(name1)
    assert_nil(blob, "transaction raise still created '#{name1}' in staging")

    assert_raises(RuntimeError, 'Transaction did not propagate error') {
      @db.transaction {
        propagate
        raise RuntimeError
      }
    }

    # test commit
    msg = 'SUCCESS'
    name, email = 'me', 'myself@i.com'
    @db.transaction { 
      author name, email
      message(msg)
      index.add('test-commit-file', 'zyxwvu')
    }
    cmt = @db.commits.last
    assert_not_nil(cmt, "transaction did not create commit")
    assert_equal(msg, cmt.message, "transaction commit has wrong message")
    assert_equal(name, cmt.author.name, "transaction commit has wrong author")
    assert_equal(email, cmt.author.email, "transaction commit has wrong email")

    # test commits in nested transaction
    num_commits = @db.commits.count
    @db.transaction { 
      index.add('trans-nested-commit-file-1', '223344')
      database.transaction {
        index.add('trans-nested-commit-file-2', 'ccddff')
        commit
      }
    }
    assert_equal(num_commits + 2, @db.commits.count, 'Nested commits failed')

    # test transaction with staging set
    @db.staging = index
    @db.transaction { index.delete(fname) }
    blob = index.current_tree./(fname)
    assert_equal(index, @db.staging, 'db.exec clobbered staging')

    # test nested transactions
    name2, data2 = 'xtest2', '~~~~~~~'
    @db.staging.clear_write_count
    @db.transaction {
      index.add(name1, data1)
      database.transaction { index.add(name2, data2) }
    }
    index.commit('etc') # existing index means both transactions are nested
    assert_equal(index, @db.staging, 'nested transaction clobbered staging')
    assert_equal(1, @db.staging.write_count, 
                 'Nested transaction caused > 1 write!')

    # verify that both files in nested exec were created
    blob = index.current_tree./(name1)
    assert_not_nil(blob, "nested db.exec did not create '#{name1}' in staging")
    assert_equal(data1, blob.data, "BLOB data for '#{name1}' does not match")

    blob = index.current_tree./(name2)
    assert_not_nil(blob, "nested db.exec did not create '#{name2}' in staging")
    assert_equal(data2, blob.data, "BLOB data for '#{name2}' does not match")

    @db.staging = nil
  end

  def test_branch

    num = @db.heads.count
    @db.branch_and_merge {
      index.add('tmp/1', '1')
    }
    assert_equal(num+1, @db.heads.count, 'Anon Branch&Merge failed!')

    name = 'named branch'
    num = @db.heads.count
    @db.branch_and_merge(name) {
      database.index.add('tmp/2', '2')
    }
    assert_equal(num+1, @db.heads.count, 'Named Branch&Merge failed!')
    assert_equal(1, @db.heads.select{ |h| h.name == @db.clean_tag(name)}.count,
                 'Named Branch not present!')

  end

end

