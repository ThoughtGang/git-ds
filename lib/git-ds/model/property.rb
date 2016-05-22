#!/usr/bin/env ruby
# :title: Git-DS::PropertyDefinition
=begin rdoc

Copyright 2011 Thoughtgang <http://www.thoughtgang.org>
=end

require 'git-ds/shared'

module GitDS

=begin rdoc
Exception raised when duplicate properties (i.e. having the same name) are
defined for a single class.
=end
  class DuplicatePropertyError < ArgumentError
    def initialize(name)
      super "Duplicate property '#{name}'"
    end
  end

=begin rdoc
Exception raised when Property#valid? returns false.
=end
  class InvalidPropertyValueError < ArgumentError
    def initialize(name, value)
      super "Invalid value '#{value}' for property '#{name}'"
    end
  end

=begin rdoc
A definition of a ModelItem property.

These are stored in the class, and are used to wrap access to properties
by ModelItem objects.
=end
  class PropertyDefinition

=begin rdoc
Name of the property, e.g. 'size'.
=end
    attr_accessor :name

=begin rdoc
Default value, e.g. '0'.
=end
    attr_accessor :default_value

=begin rdoc
Property exists on-disk as well as in the object db.
=end
    attr_accessor :on_fs

=begin rdoc
Block used to validate data when set.
=end
    attr_accessor :validation_block

    def initialize(name, default=nil, fs=false, &block)
      @name = name
      @default_value = default
      @on_fs = fs
      @validation_block = (block_given?) ? block : nil
    end

=begin rdoc
Get full path to BLOB for property based on parent directory.
=end
    def path(parent_path)
      parent_path + ::File::SEPARATOR + name.to_s
    end

=begin rdoc
Read value from ModelItem at path in Model.
This just returns the String value of the property file contents; subclasses
should wrap this with a call that will generate an Integer, List, etc from
the contents.
=end
    def get(model, parent_path)
      val = model.get_item(path(parent_path))
      val ? val.chomp : ''
    end

=begin rdoc
Write value to ModelItem at path in Model.

Note: this returns the String representation of the value as written to the
Property BLOB.
=end
    def set(model, parent_path, value)
      raise InvalidPropertyValueError.new(name, value.inspect) if not \
            valid?(value)
      val = convert_value(value)
      write(model, path(parent_path), val + "\n")
      val
    end

=begin rdoc
Convert value to its internal (in-Git) representation.
=end
    def convert_value(value)
      val = value.to_s

      if value.kind_of?(Array)
        val = value.join("\n")
      elsif value.kind_of?(Hash)
        val = value.inspect
      end

      val
    end

=begin rdoc
If property has a validation block, invoke it to determine if value is
valid. Otherwise, return true.
=end
    def valid?(value)
      blk = self.validation_block
      blk ? blk.call(value) : true
    end

    alias :default :default_value

    protected

=begin rdoc
Write 
=end
    def write(model, path, value)
      on_fs ? model.add_fs_item(path, value) : model.add_item(path, value)
    end

  end

=begin rdoc
A definition of a ModelItem property that stores binary data.
=end
  class BinaryPropertyDefinition < PropertyDefinition

=begin rdoc
Read value from ModelItem at path in Model.

This just returns the raw binary value of the property file contents.
=end
    def get(model, parent_path)
      model.get_item(path(parent_path))
    end

=begin rdoc
Write a raw binary value to ModelItem at path in Model.

Note: this returns the raw binary data as written to the Property BLOB.
=end
    def set(model, parent_path, value)
      write(model, path(parent_path), value)
      value
    end

=begin rdoc
Raw binary property values are always valid if they are not nil
=end
    def valid?(val)
      val != nil
    end
  end

=begin rdoc
A Property that is a link to a ModelItem class instance.
=end
  class ProxyProperty < PropertyDefinition
    attr_reader :obj_class
    def initialize(name, cls, fs=false, &block)
      super name, nil, fs, &block
      @obj_class = cls
    end

=begin rdoc
Write path of object to property.
=end
    def set(model, parent_path, obj)
      super model, parent_path, obj.path
    end

=begin rdoc
Instantiate object from path stored in property.
=end
    def get(model, parent_path)
      # the object path is stored in the property file
      obj_path = super model, parent_path
      @obj_class.new(model, obj_path) if obj_path && (not obj_path.empty?)
    end
  end

end
