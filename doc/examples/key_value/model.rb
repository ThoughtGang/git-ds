#!/usr/bin/env ruby
# :title: GitDS Model Example: Key/Value
=begin rdoc
<i>Copyright 2011 Thoughtgang <http://www.thoughtgang.org></i>

This example demonstrates a GitDS database that acts as a simple Key:Value
datastore.

==Usage

An example of the usage of this model can be found in the following script:

    doc/examples/key_value/test.rb

This script can be run to generate an example Git-DS repository:

    bash$ doc/examples/key_value/test.rb
    bash$ cd kv_test.db && qgit &

The following command-line utilities are provided for manipulating this 
data model:

    doc/examples/key_value/kv_get.rb
    doc/examples/key_value/kv_init.rb
    doc/examples/key_value/kv_list.rb
    doc/examples/key_value/kv_remove.rb
    doc/examples/key_value/kv_set.rb

===Initialize a Key:Value datastore

   model = KeyValueModel.new(GitDS::Database.connect('kv_test.db', true))

===Set a key:value pair

    model[key] = value

===Get a key:value pair

    model[key]

===Remove a key:value pair

    model.remove(key)

===List all key:value pairs

    model.each { |key, value| ... }
  
=end

require 'git-ds/database'
require 'git-ds/model'

# ============================================================================

=begin rdoc
A data model representing a basic Key/Value store.

This has the following structure on disk:
    key-value/            : ModelItem class for Key/Value pairs
    key-value/$KEY/value  : Property file containing value of key
=end

class KeyValueModel < GitDS::Model
  def initialize(db)
    super db, 'key/value model'
  end

=begin rdoc
Return KeyValudeModelItem for key.
=end
  def pair(key)
    path = KeyValueModelItem.instance_path(self.root.path, key)
    KeyValueModelItem.new(self, path)
  end

=begin rdoc
Return true if key exists in Model.
=end
  def include?(key)
    super KeyValueModelItem.instance_path(self.root.path, key)
  end

  alias :exist? :include?

=begin rdoc
Return value for key if it exists in model, nil otherwise.
=end
  def [](key)
    return nil if not exist? key
    p = pair(key)
    p ? p.value : nil
  end

=begin rdoc
Set value for key to 'val'. The key/value pair is created if it does not
already exist.
=end
  def []=(key, val)
    if self.exist? key
      p = pair(key)
      p.value = val if p
    else
      KeyValueModelItem.create self.root, {:key => key, :value => val}
    end
  end

=begin rdoc
Yield each key, value pair in database.
=end
  def each
    KeyValueModelItem.list(self.root).each do |k|
      yield [k, self[k]]
    end
  end

=begin rdoc
Remove a key:value pair from the database.
=end
  def remove(key)
    pair(key).delete
  end
end

=begin rdoc
A ModelItem class for Key/Value pairs. This assumes that value is a String.
To support other datatypes, subclass and override the value() accessor.
=end
class KeyValueModelItem < GitDS::ModelItem
  name 'key-value'

  property(:value, '')

=begin rdoc
Use :key as the ident field of the create() Hash.
=end
  def self.ident_key
    :key
  end

  alias :key :ident

=begin rdoc
Return the value of the key:value pair.
=end
  def value
    property(:value)
  end

=begin rdoc
Set the value of the key:value pair.
=end
  def value=(val)
    set_property(:value, val)
  end
end
