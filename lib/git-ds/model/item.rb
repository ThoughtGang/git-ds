#!/usr/bin/env ruby
# :title: Git-DS::ModelItem
=begin rdoc

Copyright 2011 Thoughtgang <http://www.thoughtgang.org>

Notes:
The children of an item will be one of the following:
  * A Property (a named BLOB containing a value)
  * A ModelItem (a subdirectory that defines a ModelItem instance)
  * A ModelItem link (a named BLOB containing a path to a ModelItem instance)
Note that ModelItems and ModelItemLinks will be in a subdirectory named for
the ModelItem, even if there is only a single entry.
=end

require 'time'  # for timestamp proprties
require 'git-ds/shared'
require 'git-ds/model/property'

module GitDS

  class InvalidModelItemPath < RuntimeError
  end

  class InvalidModelItemError < RuntimeError
  end

# ----------------------------------------------------------------------
=begin rdoc
ModelItem class methods.

Note: this is a class-method module. It should be extended in a class, not 
included.
=end
  module ModelItemClass

=begin rdoc
The name of the ModelItemClass in the database.

To be overridden by a modelitem class.
=end
    def name(name=nil)
      @name ||= nil
      raise 'ModelItemClass has no name defined' if (not name) && (not @name)
      name ? @name = name : @name
    end

=begin rdoc
Return the path to the ModelItem class owned by the specified parent.

For example, given the following database:

  ClassA/a1/ClassB/b1
  ClassA/a1/ClassB/b2
  ClassA/a2/ClassB/b3

ClassA.path(@model.root) will return 'ClassA', ClassB.path(a1) will return 
'ClassA/a1/ClassB', and ClassB.path(a2) will return 'ClassA/a2/ClassB'.
=end
    def path(parent)
      return name if not parent
      build_path(parent.path)
    end

=begin rdoc
Return the path to the ModelItem class inside the specified directory.
=end
    def build_path(parent_path)
      return name if (not parent_path) || parent_path.empty?
      parent_path + ::File::SEPARATOR + name
    end

=begin rdoc
Return the path to an instance of the object under parent_path.
=end
    def instance_path(parent_path, ident)
      path = build_path(parent_path)
      path += ::File::SEPARATOR if not path.empty?
      path += ident.to_s
    end

=begin rdoc
Return true if the specified instance of this ModelItem class exists in the
model (i.e. database has 'ident' in it already).
=end
    def exist?(parent, ident)
      parent.model.include? instance_path(parent.path, ident)
    end

=begin rdoc
List all children of this ModelItem class.

This will list all instances of the class owned by the specified parent.
For example, given the following database:

  ClassA/a1/ClassB/b1
  ClassA/a1/ClassB/b2
  ClassA/a2/ClassB/b3

ClassA.list(@model.root) will return [a1, a2], ClassB.list(a1) will return 
[b1, b2], and ClassB.list(a2) will return [b3].
=end
    def list(parent)
      list_in_path parent.model, parent.path
    end

=begin rdoc
List all children of the ModelItem class inside parent_path.
=end
    def list_in_path(model, parent_path)
      model.list_children build_path(parent_path)
    end

=begin rdoc
Generate an ident (String) from a Hash of arguments.

To be overridden by a modelitem class.
=end
    def ident(args)
      args[ident_key()].to_s
    end

=begin rdoc
The key containing the object ident in the args Hash passed to create.

This can be used to change the name of the ident key in the hash without
having to override the ident method.
=end
    def ident_key
      :ident
    end

=begin rdoc
Create a new instance of the ModelItemClass owned by the specified parent.

This will create a subdirectory under ModelItemClass.path(parent); the name
of the directory is determined by ModelItemClass.ident.

For example, given the following database:

  ClassA/a1/ClassB/b1
  ClassA/a1/ClassB/b2
  ClassA/a2/ClassB/b3

ModelItemClass.create(a2, { :ident => 'b4' } ) will create the directory
'ClassA/a2/ClassB/b4'.

The directory will then be filled by calling ModelItemClass.fill.

Note that this returns the path to the created item, not an instance.
=end
    def create(parent, args={})
      raise "Use Database.root instead of nil for parent" if not parent
      raise "parent is not a ModelItem" if not parent.respond_to? :model

      model = parent.model
      create_in_path(parent.model, parent.path, args)
    end

=begin rdoc
Create a new instance of the ModelItemClass in the specified directory.

This will create a subdirectory under parent_path; the name of the directory 
is determined by ModelItemClass.ident.

For example, given the following database:

  ClassA/a1/ClassB/b1
  ClassA/a1/ClassB/b2
  ClassA/a2/ClassB/b3

ModelItemClass.create(a2, { :ident => 'b4' } ) will create the directory
'ClassA/a2/ClassB/b4'.

The directory will then be filled by calling ModelItemClass.fill.

The creation of the objects in the model takes place within a DB transaction.
If this is called from within a transaction, it will use the existing staging
index; otherwise, it will create a new index and auto-commit on success.

Note that this returns the ident of the created item, not an instance.
=end
    def create_in_path(model, parent_path, args)
      id = ident(args)
      item_path = build_path(parent_path) + ::File::SEPARATOR + id
      raise InvalidModelItemPath if (not item_path) || item_path =~ /\000/

      # Ensure that nested calls (e.g. to create children) share index#write
      cls = self
      model.transaction {
        propagate
        cls.fill(model, item_path, args)
      }

      item_path
    end

=begin rdoc
Create all subdirectories and files needed to represent a ModelItemClass
instance in the object repository.

item_path is the full path to the item in the model.
args is a hash of arguments used to construct the item.

Can be overridden by ModelItem classes and invoked via super.
=end
    def fill(model, item_path, args)
      fill_properties(model, item_path, args)
    end

=begin rdoc
Fill all properties either with their value in 'args' or their default value.

Foreach key in properties,
  if args.include?(key) && property.valid?(key, args[key])
     set property to key
  elsif properties[key].default
     set property to default
  else ignore
=end
    def fill_properties(model, item_path, args)
      hash = properties
      hash.keys.each do |key|
        prop = hash[key]
        if args.include?(key)
          prop.set(model, item_path, args[key])
        elsif hash[key].default
          prop.set(model, item_path, prop.default)
        end
      end
    end

=begin rdoc
Define a property for this ModelItem class.
=end
    def define_db_property(name, default=0, &block)
      add_property PropertyDefinition.new(name, default, false, &block)
    end

=begin rdoc
Define an on-filesystem property for this ModelItem class.
=end
    def define_fs_property(name, default=0, &block)
      add_property PropertyDefinition.new(name, default, true, &block)
    end

=begin rdoc
Define a Property for this ModelItem class. The property will be DB-only.

This can be overridden to change how properties are stored.
=end
    def property(name, default=0, &block)
      define_db_property(name, default, &block)
    end

=begin rdoc
Define a BinaryProperty for this ModelItem class. The property will be on-FS
unless on_fs is set to false. 

Note: Properties that store raw binary data have no default value and no
validation function. They are assumed to be on-disk by default.
=end
    def binary_property(name, on_fs=true)
      add_property BinaryPropertyDefinition.new(name, nil, on_fs)
    end

=begin rdoc
Define a property that is a link to a ModelItem object.

Note: this is a link to a single ModelItem class. For a list of links to
ModelItems, use a ModelItem List of ProxyModelItemClass objects.
=end
    def link_property(name, cls, &block)
      add_property ProxyProperty.new(name, cls, false, &block)
    end
      
    alias :proxy_property :link_property

=begin rdoc
Hash of properties associated with this MOdelItem class.
=end
    def properties
      @properties ||= {}
    end

    private

=begin rdoc
Add a property to the properties Hash. This throws GitDS::DuplicatePropertyError
if a property with the same name already exists in the class.
=end
    def add_property(p)
      hash = properties
      raise DuplicatePropertyError.new(p.name) if hash.include? p.name
      hash[p.name] = p
    end
  end

# ----------------------------------------------------------------------
=begin rdoc
Instance methods used by repo-backed objects.

Note: this is an instance-method module. It should be included, not extended.
=end
  module ModelItemObject

=begin rdoc
The GitDS::Model that contains the object.
=end
    attr_reader :model

    def initialize_item(model, path)
      # NULLS in Path objects cause corrupt trees!
      raise InvalidModelItemPath if (not path) || path =~ /\000/

      @model = model
      @path = path
      @ident = File.basename(path)
    end

=begin rdoc
Full path to this item in the repo.
=end
    def path
      ensure_valid
      @path
    end

=begin rdoc
Primary key (ident) for instance.
=end
    def ident
      ensure_valid
      @ident
    end

=begin rdoc
Return list of property names.
=end
    def properties
      self.class.properties.keys
    end

=begin rdoc
List children of ModelItemClass. By default, this just lists the properties.
Classes should append non-property children (usually other modelitems) to 
this list.
=end
    def children
      properties                                                              
    end

=begin rdoc
Return Hash of cached property values.
=end
    def property_cache
      ensure_valid
      @property_cache ||= {}
    end

=begin rdoc
Clear all caches in ModelItem instance. In the base class, this just clears
the property cache.
=end
    def clear_cache
      property_cache.clear
    end

=begin rdoc
Return the value of a specific property. If the proprty has not been set,
nil is returned.

ModelItem classes will generally write property accessors that wrap the
call to this method.
=end
    def property(name)
      ensure_valid
      return property_cache[name] if property_cache.include? name
      prop = self.class.properties[name]
      raise "No such property #{name}" if not prop
      property_cache[name] = prop.get(@model, @path)
    end

=begin rdoc
Convenience method for reading Integer properties.
=end
    def integer_property(name)
      val = property(name)
      val ? property_cache[name] = val.to_i : nil
    end

    alias :i_property :integer_property

=begin rdoc
Convenience method for reading Float properties.
=end
    def float_property(name)
      val = property(name)
      val ? property_cache[name] = val.to_f : nil
    end

    alias :f_property :float_property

=begin rdoc
Convenience method for reading Time (aka timestamp) properties.
=end
    def timestamp_property(name)
      val = property(name)
      if val && (not val.kind_of? Time)
        val = (not val.empty?) ? Time.parse(val) : nil
        property_cache[name] = val
      end
      val
    end

    alias :ts_property :timestamp_property

=begin rdoc
Convenience method for reading Boolean properties.
=end
    def bool_property(name)
      val = property(name)
      (val && val == 'true')
    end

    alias :b_property :bool_property

=begin rdoc
Convenience method for reading Array properties.

Note that this returns an Array of Strings.

Note: the default delimiter is what Property uses to encode Array objects.
Classes which perform their own encoding can choose a different delimiter.
=end
    def array_property(name, delim="\n")
      val = property(name)
      if val && (not val.kind_of? Array)
        val = (val.empty?) ? [] : val.split(delim)
        property_cache[name] = val
      end
      val
    end

    alias :a_property :array_property

=begin rdoc
Set the value of a specific property.

ModelItem classes will generally write property accessors that wrap the
call to this method.
=end
    def set_property(name, data)
      ensure_valid
      prop = self.class.properties[name]
      raise "No such property #{name}" if not prop
      property_cache[name] = prop.set(@model, @path, data)
    end

=begin rdoc
=end
    def delete
      ensure_valid
      @model.delete_item(@path)
      # invalidate object
      @path = nil
    end

=begin rdoc
Return true if item is valid, false otherwise.
=end
    def valid?
      @path   # an invalid item has a nil path
    end

    protected

=begin rdoc
Raises an InvalidModelItemError if item is not valid.

Note: accessors for non-property children should invoke this before 
touching the object.
=end
    def ensure_valid
      raise InvalidModelItemError if not valid?
    end

  end

end
