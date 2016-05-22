#!/usr/bin/env ruby
# Test the TestSuite database example
# Copyright 2011 Thoughtgang <http://www.thoughtgang.org>

BASE=File.dirname(File.expand_path(__FILE__)\
                 ).split(File::SEPARATOR)[0..-4].join(File::SEPARATOR)
$: << BASE + File::SEPARATOR + 'lib'
$: << BASE + File::SEPARATOR + 'doc' + File::SEPARATOR + 'examples'

require 'test_suite/ts_list'

# ----------------------------------------------------------------------

def fill_model(model)

  modules = {
    'projects/thing/include/thing.h' => "void thing();\n" ,
    'projects/thing/include/arch/arm.h' => "#define ARM\n" ,
    'projects/thing/include/arch/x86.h' => "#define X86\n" ,
    'projects/thing/src/thing.c' => "void thing() { /* nop */ }\n" ,
    'projects/thing/src/ops.c' => "void ops(){ /* nop */ }\n" ,
    'projects/thing/src/util.c' => "void util() { /* nop */ }\n" ,
    'projects/shared/libstuff/include/stuff.h' => "int stuff();" ,
    'projects/shared/libstuff/src/stuff.c' => "int stuff() { return 1; }" 
  }

  test_suites = {
    'Development' => { :description => 'Performed during active development',
            :tests => {
              'thing_thing' => [
                'projects.thing.include.thing.h',
                'projects.thing.src.thing.c'
                               ],
              'thing_arm' => [
                'projects.thing.include.arch.arm.h',
                'projects.thing.include.thing.h',
                'projects.thing.src.thing.c'
                             ],
              'thing_x86' => [
                'projects.thing.include.arch.x86.h',
                'projects.thing.include.thing.h',
                'projects.thing.src.thing.c'
                             ],
              'thing_ops' => [ 'projects.thing.src.ops.c' ],
              'thing_util' => [ 'projects.thing.src.util.c' ]
            } },
    'QA' => { :description => 'Performed by QA department',
            :tests => {
              'thing_regression' => [
                'projects.thing.src.thing.c',
                'projects.thing.src.ops.c',
                'projects.thing.src.util.c',
                'projects.thing.include.thing.h'
              ],
              'stuff_regression' => [
                'projects.shared.libstuff.include.stuff.h',
                'projects.shared.libstuff.src.stuff.c'
              ]
            } },
    'Release' => { :description => 'Performed on a release candidate',
            :tests => {
              'thing_integration' => [
                'projects.thing.src.thing.c',
                'projects.thing.src.ops.c',
                'projects.thing.src.util.c',
                'projects.thing.include.thing.h'
              ],
              'stuff_integration' => [
                'projects.shared.libstuff.include.stuff.h',
                'projects.shared.libstuff.src.stuff.c'
              ]
            } }
  }

  bugs = {
    1200 => { :description => 'Thing calculates wrong value',
              :tests => [
                ['Development', 'thing_thing'],
                ['QA', 'thing_regression'],
                ['Release', 'thing_integration']
              ] },
    1201 => { :description => 'Memory leak in stuff',
              :tests => [
                ['QA', 'stuff_regression'],
                ['Release', 'stuff_integration']
              ] },
    1202 => { :description => 'SEGV in thing',
              :tests => [
                ['Development', 'thing_thing'],
                ['Development', 'thing_util'],
                ['QA', 'thing_regression']
              ] },
    'v1-user-nologin' => { :description => 'User cannot log in (Version 1)',
                           :tests => [ ['Release', 'thing_integration'] ] }
  }

  modules.each do |path, data|
    model.add_module(path, data)
  end

  test_suites.each do |name, h|
    s = model.add_test_suite(name, h[:description])
    h[:tests].each do |name, arr|
      mods = arr.inject([]) { |arr, ident| arr << model.module(ident) }
      s.add_test(name, mods)
    end
  end

  bugs.each do |name, h|
    b = model.add_bug(name, h[:description])
    h[:tests].each do |arr|
      s = model.test_suite(arr[0])
      t = s.test(arr[1])
      b.add_test(t)
    end
  end

end

def run_tests(db_path)
  db = GitDS::Database.connect_as(db_path, 'tony b', 'tony@disco.net')
  raise "Could not connect to db!" if not db

  model = TestSuiteModel.new(db)
  model.branched_transaction('TonyTesting') {
    model.perform_tests { |t| t.perform(true) }
    model.update_bugs
  }
  db.mark('Tony testing complete')
  db.close

  db = GitDS::Database.connect_as(db_path, 'bill p', 'bill@stallynz.net')
  raise "Could not connect to db!" if not db

  model = TestSuiteModel.new(db)
  db.unstage
  model.branched_transaction('QATesting') {
    s = model.test_suite('QA')
    s.tests.each do |ident|
      t = s.test(ident)
      t.perform(false, 'QA deemed results unworthy')
    end
    model.update_bugs
  }
  db.mark('QA testing complete')
  db.close
end

# ----------------------------------------------------------------------
def list_model(model)
  list_modules(model, true)
  list_suites(model, true)
  list_bugs(model, true)
end

# ----------------------------------------------------------------------
if __FILE__ == $0
  path = (ARGV.count > 0) ? ARGV.shift : 'ts_test.db'

  db = GitDS::Database.connect(path, true)
  model = TestSuiteModel.new(db) if db
  raise "Could not connect to model" if not model

  model.branched_transaction('FillModel') do 
    fill_model(model)
  end
  db.mark('Initial data input')

  run_tests(path)

  list_model(model)
end

