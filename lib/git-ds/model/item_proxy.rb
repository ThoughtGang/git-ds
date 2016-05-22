#!/usr/bin/env ruby
# :title: Git-DS::ModelItemProxy
=begin rdoc

Copyright 2011 Thoughtgang <http://www.thoughtgang.org>
=end

require 'git-ds/model/item_list'

module GitDS

=begin rdoc
Exception raised by errors in creating ModelItemClassProxy instances, e.g.
bad target or link path.
=end
  class ProxyItemError < RuntimeError
  end

=begin rdoc
Proxy a ModelItem class.

This is used to store a link to a ModelItem class instance. A ModelItemList can
be passed a ModelItemClassProxy instance as its cls parameter in order to
store a list of links to ModelItem class instances.
=end
  class ModelItemClassProxy

    def initialize(cls)
      @true_class = cls
    end

=begin rdoc
List ModelItem class instances contained in this list.

Note: this is passed to the proxied class, as it is just a list of idents.

Instantiating and adding an ident is handled by this class.
=end
    def list_in_path(model, path)
      @true_class.list_in_path(model, path)
    end

=begin rdoc
Return instance of ModelItem class for 'ident'.
=end
    def new(model, link_path)
      # read path to ModelItem instance from link file at 'link_path'
      instance_path = model.get_item(link_path)
      raise ProxyItemError.new("Invalid ProxyItem path: #{link_path}") if \
            (not instance_path) || (instance_path.empty?)

      @true_class.new(model, instance_path.chomp)
    end

=begin rdoc
This is passed to the proxied class, as it just returns class_dir + ident.
=end
    def instance_path(base_path, ident)
      @true_class.instance_path(base_path, ident)
    end

=begin rdoc
Create a link to ModelItem.

The ModelItem class ident() method will be used to find the ident of the
instance in the args Hash.

The full path to the instance is expected to be in the :path key of the args
Hash.

If args[:fs] is not nil or false, the link file will be created on-filesystem
as well as in-db.
=end
    def create(parent, args)
      link_path = instance_path(parent.path, @true_class.ident(args))
      raise ProxyItemError.new("Invalid ProxyItem path: #{link_path}") if \
            (not link_path) || (link_path.empty?)

      path = args[:path]
      raise ProxyItemError.new('Invalid ModelItem path') if (not path) || \
            (path.empty?)

      # write path to ModelItem into link file at 'instance path'
      args[:fs] ? parent.model.add_fs_item(link_path, path.to_s + "\n") \
                : parent.model.add_item(link_path, path.to_s + "\n")
    end

  end

=begin rdoc
A generic list of links to ModelItemClass instance of a specific class.

Example:
     class a/1/name
     class a/1/data
     class a/2/name
     class a/2/data
     class b/1/a/1
     class b/1/a/2
class b/$ID/a is a list of links to class a objects.
=end
  class ProxyItemList < ModelItemList

    def initialize(cls, model, path)
      @true_class = cls
      @proxy_class = ModelItemClassProxy.new(cls)
      super @proxy_class, model, path
    end

=begin rdoc
Add a link to 'obj' to the list.
=end
    def add(parent, obj, on_fs=false)
      args = { :path => obj.path, :fs => on_fs }
      args[@true_class.ident_key] = obj.ident
      super parent, args
    end

=begin rdoc
Delete a link from the list. This does not delete the object that was linked
to.
=end
    def delete(ident)
      @model.delete_item @proxy_class.instance_path(@base_path, ident)
    end
  end

end
