#!/usr/bin/env ruby
# Copyright 2011 Thoughtgang <http://www.thoughtgang.org>
# Unit test for Git-DS Model class

require 'test/unit'
require 'fileutils'

require 'git-ds/database'
require 'git-ds/model'


# =============================================================================
# Generic class inheriting ModelItem modules
class TestModelItem 
  include GitDS::ModelItemObject
  extend GitDS::ModelItemClass

  def initialize(model, path)
    initialize_item(model, path)
  end
end

# ----------------------------------------------------------------------
# Generic DB ModelItem

class TestDbModelItem < GitDS::ModelItem
  name 'db-test-item'
  property(:data, 'data')

  def data=(val)
    set_property(:data, val)
  end

  # accessors for treatig property value as different types
  def i_property
    integer_property(:data)
  end

  def s_property
    property(:data)
  end

  def f_property
    float_property(:data)
  end

  def t_property
    ts_property(:data)
  end

  def a_property
    array_property(:data)
  end

end

# ----------------------------------------------------------------------
# Generic FS ModelItem

class TestFsModelItem < GitDS::FsModelItem
  name 'fs-test-item'
  property(:data, 'data')
end

# =============================================================================
class TC_GitModelTest < Test::Unit::TestCase
  TMP = File.dirname(__FILE__) + File::SEPARATOR + 'tmp'

  attr_reader :db, :model

  def setup
    FileUtils.remove_dir(TMP) if File.exist?(TMP)
    Dir.mkdir(TMP)
    path = TMP + File::SEPARATOR + 'model_test'
    @db = GitDS::Database.new(path)
    @model = GitDS::Model.new(@db)
  end

  def teardown
    FileUtils.remove_dir(TMP) if File.exist?(TMP)
  end

  # ----------------------------------------------------------------------

  def test_config
    assert_equal('', @model.config['the test'], 'Test cfg entry not empty')
    assert_equal('model-generic.the-test', @model.config.path('the test'), 
                 'Config object generated wrong path')
    @model.config['the test'] = 'zyx'
    assert_equal('zyx', @model.config['the test'], 'Cfg string incorrect')
  end

  def test_model_item
    assert_raises(RuntimeError, 'ModelItemClass has no name defined') {
      TestModelItem.name
    }
    assert_raises(RuntimeError, 'parent is not a ModelItem') {
      TestModelItem.create("root")
    }
    assert_raises(RuntimeError, 'Use Database.root instead of nil for parent') {
      TestModelItem.create("root")
    }
  end

  # ----------------------------------------------------------------------
  def test_db_model_item
    assert_equal(0, @db.list(TestDbModelItem.path(@model.root)).count, 
                 '>0 DbItems in database by default')
    assert_equal(0, TestDbModelItem.list(@model.root).count,
                 '>0 DbItems in model by default')

    # create an in-DB ModelItem
    id = '101'
    data = '00110011'
    TestDbModelItem.create @model.root, {:ident => id, :data => data }

    # is item in DB?
    assert_equal(1, @db.list(TestDbModelItem.path(@model.root)).count, 
                 'FsModelItem not created in DB')
    assert_equal(1, TestDbModelItem.list(@model.root).count,
                 'FsModelItem not created in model')
    # is item NOT on FS?
    @db.exec_in_git_dir {
      assert( (not File.exist? TestDbModelItem.name + File::SEPARATOR + id),
             "TestDbModelItem creates file on disk!")
    }

    assert_equal(id, TestDbModelItem.list(@model.root).first,
                 'Could not list DbModelItem')

    path = TestDbModelItem.instance_path(@model.root.path, id)
    o = TestDbModelItem.new(@model, path)
    assert_equal(id, o.ident, 'Could not insantiate DbModelItem')
    assert_equal(data, o.property(:data), 'DbModelItem data does not match')

    o.delete
    assert_equal(0, TestDbModelItem.list(@model.root).count,
                 'DbModelItem delete failed')
  end

  # ----------------------------------------------------------------------
  def test_fs_model_item
    assert_equal(0, @db.list(TestFsModelItem.path(@model.root)).count, 
                 '>0 FsItems by default!')
    assert_equal(0, TestFsModelItem.list(@model.root).count,
                 '>0 FsItems in model by default')

    # create an on-FS ModelItem
    id = '102'
    data = '11223344'
    TestFsModelItem.create @model.root, {:ident => id, :data => data }

    # is item in DB?
    assert_equal(1, @db.list(TestFsModelItem.path(@model.root)).count, 
                 'FsModelItem not created in DB')
    assert_equal(1, TestFsModelItem.list(@model.root).count,
                 'FsModelItem not created in model')
    # is item on FS?
    @db.exec_in_git_dir {
      assert( (File.exist? TestFsModelItem.name + File::SEPARATOR + id),
              "TestFsModelItem did not create file on disk")
    }

    assert_equal(id, TestFsModelItem.list(@model.root).first,
                 'Could not list FsModelItem')

    path = TestFsModelItem.instance_path(@model.root.path, id)
    o = TestFsModelItem.new(@model, path)
    assert_equal(id, o.ident, 'Could not insantiate FsModelItem')
    assert_equal(data, o.property(:data), 'FsModelItem data does not match')

    o.delete
    assert_equal(0, TestDbModelItem.list(@model.root).count,
                 'DbModelItem delete failed')
  end

  # ----------------------------------------------------------------------
  def test_modelitem_list
    id = ['aa', 'ab', 'ac', 'ad']
    data = ['10', '11', '12', '13']
    id.each_with_index do |i, idx|
      TestDbModelItem.create @model.root, {:ident => i, :data => data[idx] }
    end

    items = GitDS::ModelItemList.new(TestDbModelItem, @model, @model.root.path)
    assert_equal(id.count, items.keys.count, 'items list count incorrect')

    o = items[id[1]]
    assert_equal(id[1], o.ident, 'Could not insantiate FsModelItem')
    assert_equal(data[1], o.property(:data), 'FsModelItem data does not match')

    new_id = 'ae'
    new_data = '14'
    items.add @model.root, {:ident => new_id, :data => new_data }
    assert_equal(id.count+1, items.keys.count, 'items list count incorrect')

    o = items[new_id]
    assert_equal(new_id, o.ident, 'Could not insantiate FsModelItem')
    assert_equal(new_data, o.property(:data), 'FsModelItem data does not match')

    # Test convenience methods
    assert_equal(id[0], items.first, 'ModelItemList#first failed')
    assert_equal(new_id, items.last, 'ModelItemList#last failed')
    assert_equal(items.keys.count, items.count, 'ModelItemList#count failed')

    # Test Enumerable
    arr = []
    items.each { |x| arr << x }
    assert_equal(items.keys, arr, 'ModelItemList#each is broken')
    assert_equal(items.keys.sort, items.sort, 'ModelItemList#sort failed')
    assert_equal(id[0], items.min, 'ModelItemList#min failed')
    assert_equal(id[3], items.reject{ |i| i != id[3] }.first, 
                 'ModelItemList#reject failed')
    assert_equal(id[2], items.select{ |i| i == id[2] }.first, 
                 'ModelItemList#select failed')
  end

  def test_properties
    props = TestDbModelItem.properties.keys
    assert_equal(1, props.count, '> 1 property in TestDbModelItem')
    assert_equal(:data, props.first, ':data property not in TestDbModelItem')

    id, data = 'aAa', 'fubar'
    TestDbModelItem.create @model.root, {:ident => id, :data => data }

    path = TestDbModelItem.instance_path(@model.root.path, id)
    o = TestDbModelItem.new(@model, path)

    assert_equal(data, o.s_property, 'String property conversion failed')

    o.data = 378
    assert_equal(378, o.i_property, 'Integer property conversion failed')

    ts = Time.now
    o.data = ts
    assert_equal(ts.to_s, o.t_property.to_s, 'Time property conversion failed')

    o.data = 1.25
    assert_equal(1.25, o.f_property, 'Float property conversion failed')

    arr = ['a', 'b', 'c']
    o.data = arr
    assert_equal(arr, o.a_property, 'String Array property conversion failed')

    arr = [1, 2, 3]
    o.data = arr
    assert_equal(arr, o.a_property.map{ |x| x.to_i }, 'Int Array prop failed')

    arr = [1.1, 2.2, 3.3]
    o.data = arr
    assert_equal(arr, o.a_property.map{ |x| x.to_f }, 'Float Array prop failed')

    props = o.properties
    assert_equal(1, props.count, '> 1 property in TestDbModelItem obj')
    assert_equal(:data, props.first, ':data prop not in TestDbModelItem obj')

    assert_equal(1, o.property_cache.count, 'Incorrect property cache count')
    o.property_cache.clear()

    assert_equal(0, o.property_cache.count, 'property cache clear failed')

    o.delete
    
    assert_raises(GitDS::DuplicatePropertyError, 'DuplicateProperty ! thrown') {
      eval "
      class TestDupeModelItem < GitDS::ModelItem
        name 'testdupe'
        property(:data, 0)
        property(:data, '')
      end
    "
    }

  end

  def test_modelitem_proxy
    id = ['a1', 'a2', 'a3']
    data = ['01', '02', '03']

    proxy_class = GitDS::ModelItemClassProxy.new(TestDbModelItem)
    assert_equal(TestDbModelItem.instance_path(@model.root.path, id[0]),
                 proxy_class.instance_path(@model.root.path, id[0]),
                 'Proxy instance_path differs from class instance_path')

    # create ModelItems
    id.each_with_index do |i, idx|
      TestDbModelItem.create @model.root, {:ident => i, :data => data[idx] }
    end
    assert_equal(3, TestDbModelItem.list_in_path(@model,@model.root.path).count,
                 'DbModelItem not created')
    assert_equal(TestDbModelItem.list_in_path(@model, @model.root.path),
                 proxy_class.list_in_path(@model, @model.root.path),
                 'Proxy list_in_path differs from class list_in_path')

    # create a link from item 1 to item 0
    path = TestDbModelItem.instance_path(@model.root.path, id[1])
    parent = TestDbModelItem.new(@model, path)
    path = TestDbModelItem.instance_path(@model.root.path, id[0])
    target = TestDbModelItem.new(@model, path)
    proxy_class.create(parent, {:path => target.path, :ident => target.ident})

    # list and instantiate links
    ids = TestDbModelItem.list(parent)
    assert_equal(1, ids.count, 'Link not created!')
    linked = proxy_class.new(@model, 
                             proxy_class.instance_path(parent.path, ids[0]))
    assert_equal(target.ident, linked.ident, 'Linked item != target (ident)')
    assert_equal(target.property(:data), linked.property(:data), 
                 'Linked item does not match item data')

    # create proxy list in item 2
    path = TestDbModelItem.instance_path(@model.root.path, id[2])
    parent = TestDbModelItem.new(@model, path)
    items = GitDS::ModelItemList.new(proxy_class, @model, parent.path)

    path = TestDbModelItem.instance_path(@model.root.path, id[0])
    tgt1 = TestDbModelItem.new(@model, path)
    proxy_class.create(parent, {:path => tgt1.path, :ident => tgt1.ident})
    assert_equal(1, items.keys.count, 'ProxyItemList has wrong count')

    path = TestDbModelItem.instance_path(@model.root.path, id[1])
    tgt2 = TestDbModelItem.new(@model, path)
    items.add(parent, {:path => tgt2.path, :ident => tgt2.ident})
    assert_equal(2, items.keys.count, 'ProxyItemList has wrong count')

    linked = proxy_class.new(@model, 
                             proxy_class.instance_path(parent.path, ids[0]))
    assert_equal(tgt1.ident, linked.ident, 'Linked item != target (ident)')
    assert_equal(tgt1.property(:data), linked.property(:data), 
                 'Linked item does not match item data')

    # test exceptions on create, new
    assert_raises(GitDS::ProxyItemError, 'No exception on bad link path') {
      linked = proxy_class.new(@model, 
                               proxy_class.instance_path(parent.path, 'zz'))
    }
    assert_raises(GitDS::ProxyItemError, 'No exception on bad target path') {
      proxy_class.create(parent, {:ident => tgt1.ident})
    }
    assert_raises(GitDS::ProxyItemError, 'No exception on bad target path') {
      proxy_class.create(parent, {:ident => tgt1.ident, :path => ''})
    }
  end

  def model_save(tag, &block)
      opts = { :name => tag, :msg => tag }

      if block_given?
        tag = @model.db.clean_tag(tag)
        @model.branched_transaction(tag, &block)
        # @model.branch = tag  # set current branch to tag
        @model.db.merge_branch(tag)
      end

      sha = @model.db.staging.commit(opts[:msg])
      @model.db.tag_object(opts[:name], sha)
      @model.db.unstage
  end

  def test_branch
    num = @model.db.heads.count
    @model.db.staging = nil
    @model.branched_transaction {
      index.add('tmp/1', '1')
    }
    assert_equal(num+1, @model.db.heads.count, 'Anon BranchTransaction failed')

    name = 'named branch transaction'
    num = @model.db.heads.count
    @model.branched_transaction(name) {
      index.add('tmp/2', '2')
    }
    assert_equal(num+1, @model.db.heads.count, 'Named BranchTransaction failed')
    assert_equal(1, 
          @model.db.heads.select{|h| h.name == @model.db.clean_tag(name)}.count,
          'Named BranchTransaction not present.')

    # Model#save test
    index = @model.db.staging
    index.add('.stuff/canary', 'abcdef', false)
    index.commit('done')
    @model.db.unstage

    model = @model
    model_save('v1') do |opts|
      model.db.stage.add('tmp/save_1', '1', true)
    end

    model_save('v2') do |opts|
      model.db.stage.add('tmp/save_2', '2', true)
    end

  end

end

