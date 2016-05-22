#!/usr/bin/env ruby
# Test Key/Value database example
# Copyright 2011 Thoughtgang <http://www.thoughtgang.org>

BASE=File.dirname(File.expand_path(__FILE__)\
                 ).split(File::SEPARATOR)[0..-4].join(File::SEPARATOR)
$: << BASE + File::SEPARATOR + 'lib'
$: << BASE + File::SEPARATOR + 'doc' + File::SEPARATOR + 'examples'

require 'key_value/model'

# ----------------------------------------------------------------------

def fill_model(model)
  model.exec do
    {
      :a => 1,
      :b => 2,
      :c => 3
    }.each { |k,v| model[k] = v }
  end

  model.db.set_author('a user', 'au@users.net')

  model.exec do
    {
      :a => 999,
      :b => 998,
      :c => 997,
      :d => 996,
      :e => 995
    }.each { |k,v| model[k] = v }
  end
end

# ----------------------------------------------------------------------
def list_model(model)
  model.each { |k, v| puts "#{k} : #{v}" }
end

# ----------------------------------------------------------------------
if __FILE__ == $0
  path = (ARGV.count > 0) ? ARGV.shift : 'kv_test.db'

  db = GitDS::Database.connect(path, true)
  model = KeyValueModel.new(db) if db
  fill_model(model) if model
  list_model(model) if model
end

