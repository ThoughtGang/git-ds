#!/usr/bin/env ruby
# :title: GitDS Model Example: Test Suite
# :doc:
=begin rdoc
<i>Copyright 2011 Thoughtgang <http://www.thoughtgang.org></i>

This example is suitable for demonstrating branches, commits, tags, and 
actions by multiple users.

The TestSuite model consists of Modules (source code files), Test Suites
(collections of tests), Tests (specific test instances), and Bugs (bug
reports). Tests can be associated with modules (which they verify), and Bugs 
can be associated with Tests (which cause them to be manifest). Tests have
a pass/fail state which is updated over time as they are performed, and Bugs
have an open/closed state which is updated over time as the Tests which 
detect them pass or fail.

Note: This is not a serious proposal for a bug-tracking data model. It is
intended only to serve as an example of a data model with frequent changes by
multiple users.

==Usage

An example of the usage of this model can be found in the following script:

    doc/examples/test_suite/test.rb

This script can be run to generate an example Git-DS repository:

    bash$ doc/examples/test_suite/test.rb
    bash$ cd ts_test.db && qgit &

The following command-line utilities are provided for manipulating this 
data model:

    doc/examples/test_suite/ts_add_bug.rb
    doc/examples/test_suite/ts_add_module.rb
    doc/examples/test_suite/ts_add_module_to_test.rb
    doc/examples/test_suite/ts_add_test.rb
    doc/examples/test_suite/ts_add_test_suite.rb
    doc/examples/test_suite/ts_add_test_to_bug.rb
    doc/examples/test_suite/ts_init.rb
    doc/examples/test_suite/ts_list.rb
    doc/examples/test_suite/ts_perform_test.rb
    doc/examples/test_suite/ts_update_bugs.rb

===Initialize a TestSuite database

  # connect the model, creating it if necessary
  model = TestSuiteModel.new(GitDS::Database.connect('ts_test.db', true))

  # connect as a specific user (Git author)
  model = TestSuiteModel.new(GitDS::Database.connect_as('ts_test.db'
                                                        username, email))

===Add a Source Module

  m = model.add_module(path, data)

===Add a Test Suite

  s = model.add_test_suite(name, description)

===Add Tests to a Test Suite

  t = s.add_test(name)

  # Add a test with a list of modules
  modules [ 'path.to.module.1', 'path.to.module.2' ]
  t = suite.add_test(name, modules)

  # Add a specific Module to a Test
  m = model.module('path.to.module.3'
  t.add_module(m)

===Add a Bug Report

  b = model.add_bug(name, description)

  # Add a specific test to a Bug
  s = model.suite('UnitTests')
  t = s.test('test_foo')
  b.add_test(t)

===Updating Tests and Bugs

  # Pass a block to perform_tests to update each test
  model.perform_tests do |t|

    # Generate the new pass/fail state and log for the test.
    # In reality, this might invoke and monitor a test method or program.
    passed = false
    log = "RuntimeError in..."

    # Write the new pass/fail state and log to the test
    t.perform( passed, log )
  end

  # Update all Bugs to be open or closed depending on the state of their Tests
  model.update_bugs

=end

require 'git-ds/database'
require 'git-ds/model'

# =============================================================================

=begin rdoc
The model has the following structure in the repo:

   module/                           : ModelItem class
   module/$NAME                      : ModelItem class instance
   module/$NAME/data                 : Property (str)
   module/$NAME/path                 : Property (str)
   bug/                              : ModelItem class
   bug/$ID                           : ModelItem class instance
   bug/$ID/test                      : ProxyItemList
   bug/$ID/description               : Property (str)
   bug/$ID/open                      : Property (bool)
   test_suite/                       : ModelItem class
   test_suite/$ID                    : ModelItem class instance
   test_suite/description            : Property (str)
   test_suite/$ID/test               : ModelItem class
   test_suite/$ID/test/$ID           : ModelItem class instance
   test_suite/$ID/test/$ID/module    : ProxyItemList
   test_suite/$ID/test/$ID/pass      : Property (bool)
   test_suite/$ID/test/$ID/log       : Property (str)
   test_suite/$ID/test/$ID/timestamp : Property (ts)
=end

class TestSuiteModel < GitDS::Model
  def initialize(db)
    super db, 'test-suite model'
  end

=begin rdoc
Add a Module to the database.
=end
  def add_module(path, data)
    args = { :ident => 
             path.split(File::SEPARATOR).reject{ |x| x.empty? }.join('.'),
             :name => File.basename(path), :path => File.dirname(path), 
             :data => data }
    ModuleModelItem.new self, ModuleModelItem.create(self.root, args)
  end

=begin rdoc
List all Modules in the database.
=end
  def modules
    ModuleModelItem.list(self.root)
  end

=begin rdoc
Instantiate a Module.
=end
  def module(ident)
    path = ModuleModelItem.instance_path(self.root.path, ident)
    ModuleModelItem.new self, path
  end

=begin rdoc
Add a Bug to the database.
=end
  def add_bug(ident, description)
    args = { :ident => ident, :description => description }
    BugModelItem.new self, BugModelItem.create(self.root, args)
  end

=begin rdoc
List the IDs of all Bug in the database.
=end
  def bugs
    BugModelItem.list(self.root)
  end

=begin rdoc
Instantiate a Bug.
=end
  def bug(ident)
    BugModelItem.new self, BugModelItem.instance_path(self.root.path, ident)
  end

=begin rdoc
Update the status of all Bugs.
=end
  def update_bugs
    model = self
    exec {
      model.bugs.each do |ident|
        b = model.bug(ident)
        b.update
      end
    }
  end

=begin rdoc
Add a TestSuite to the database.
=end
  def add_test_suite(ident, description)
    args = { :ident => ident, :description => description }
    TestSuiteModelItem.new self, TestSuiteModelItem.create(self.root, args)
  end

=begin rdoc
List all TestSuitesin the database.
=end
  def test_suites
    TestSuiteModelItem.list(self.root)
  end

=begin rdoc
Instantiate a TestSuite.
=end
  def test_suite(ident)
    path = TestSuiteModelItem.instance_path(self.root.path, ident)
    TestSuiteModelItem.new self, path
  end

=begin rdoc
Perform all tests in all TestSuites.
This yields each Test to the supplied block.
=end
  def perform_tests(&block)
    model = self
    exec {
      model.test_suites.each do |ident|
        s = model.test_suite(ident)
        s.perform_tests(&block)
      end
    }
  end
end

# ----------------------------------------------------------------------
=begin rdoc
A module for testing. Usually a source code file.
=end
class ModuleModelItem < GitDS::FsModelItem
  name 'module'

  property :name
  property :path
  property :data
  
=begin rdoc
Contents of the module. This will usually be source code.
=end
  def data
    property(:data)
  end

  def data=(val)
    set_property(:data, val)
  end

=begin rdoc
Name of the module in the filesystem.
=end
  def name
    property(:name)
  end

=begin rdoc
Path of the module in the filesystem.
=end
  def path
    property(:path)
  end
end

# ----------------------------------------------------------------------
=begin rdoc
A collection of tests.
=end
class TestSuiteModelItem < GitDS::ModelItem
  name 'test_suite'

  property :description

  def initialize(model, path)
    super
    @tests = GitDS::ModelItemList.new(TestModelItem, model, path)
  end

=begin rdoc
Description (e.g. purpose) of the tests.
=end
  def description
    property(:description)
  end

  def description=(val)
    set_property(:description, val)
  end

=begin rdoc
List all tests in suite.
=end
  def tests
    ensure_valid
    @tests.keys
  end

=begin rdoc
Instantiate Test object.
=end
  def test(ident)
    ensure_valid
    @tests[ident]
  end

=begin rdoc
Add a test to this suite.
=end
  def add_test( ident, modules = [] )
    ensure_valid
    t = TestModelItem.new @model, @tests.add(self, { :ident => ident } )
    modules.each { |m| t.add_module(m) }
  end

=begin rdoc
Delete a test from this suite.
=end
  def del_test(ident)
    ensure_valid
    @tests.delete(ident)
  end

=begin rdoc
Perform all tests in this TestSuite.
This yields each Test to the supplied block. The code in the block is
expected to update the Test object Properties :pass and :log.
=end
  def perform_tests(&block)
    suite = self
    @model.exec {
      suite.tests.each do |ident|
        t = suite.test(ident)
        yield t
      end
    }
  end
end

# ----------------------------------------------------------------------
=begin rdoc
A specific test.
This identifies a specific test which is associated with one or more Modules.
The testing software will invoke the perform method for each test it runs in
order to update the test results in the database.
=end
class TestModelItem < GitDS::ModelItem
  name 'test'

  property :pass, false
  property :log, ''
  property :timestamp

  def self.fill(model, item_path, args)
    super
    # Note: by default, all tests are pass=false and timestamp=create_time
    properties[:timestamp].set(model, item_path, Time.now.to_s)
  end

  def initialize(model, path)
    super
    @modules = GitDS::ProxyItemList.new(ModuleModelItem, model, path)
  end

=begin rdoc
Store the results of performing a test.
=end
  def perform(pass, log='', timestamp=Time.now)
    set_property(:pass, pass)
    set_property(:log, log)
    set_property(:timestamp, timestamp)
  end

=begin rdoc
The timestamp of the latest run of the test.
=end
  def timestamp
    ts_property(:timestamp)
  end

=begin rdoc
The result of the latest run of the test.
=end
  def pass?
    bool_property(:pass)
  end

=begin rdoc
The log from the latest run of the test.
=end
  def log
    property(:log)
  end

=begin rdoc
List all modules associated with this test.
=end
  def modules
    ensure_valid
    @modules.keys
  end

=begin rdoc
Associate a module with this test.
=end
  def add_module(m)
    ensure_valid
    @modules.add(self, m, true)
  end
end

# ----------------------------------------------------------------------
=begin rdoc
A bug report. This includes a description of the bug and an open/closed status.
A Bug is associated with one or more Tests that cause the Bug to occur.
Bugs should be closed when none of their tests fail; this can be handled
automatically by calling Bug#update after performing tests.
=end
class BugModelItem < GitDS::ModelItem
  name 'bug'

  property :description
  property :open, true

  def initialize(model, path)
    super
    @tests = GitDS::ProxyItemList.new(TestModelItem, model, path)
  end

=begin rdoc
Description of the bug and its effects.
=end
  def description
    property(:description)
  end

  def description=(val)
    set_property(:description, val)
  end

=begin rdoc
Status of the bug: open or closed?
=end
  def open?
    bool_property(:open)
  end

  def open=(val)
    set_property(:open, val)
  end

=begin rdoc
Tests which demonstrate the buig.
=end
  def tests
    ensure_valid
    @tests.keys
  end

=begin rdoc
Associated a test with this bug.

Note: t is a TestModelItem object.
=end
  def add_test( t )
    ensure_valid
    @tests.add(self, t )
  end

=begin rdoc
Delete a test from this suite.
=end
  def del_test(ident)
    ensure_valid
    @tests.delete(ident)
  end

=begin rdoc
Update the status of the bug: open if any of the tests fail, closed if all
of the tests pass.
=end
  def update
    pass_all = true
    tests.each do |ident|
      test = @tests[ident]
      pass_all = false if not test.pass?
    end

    # pass_all should equal !open
    if pass_all == open?
      open = (not pass_all)
    end
  end

end

