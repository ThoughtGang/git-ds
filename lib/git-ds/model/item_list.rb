#!/usr/bin/env ruby
# :title: Git-DS::ModelItemList
=begin rdoc

Copyright 2011 Thoughtgang <http://www.thoughtgang.org>
=end

module GitDS

=begin rdoc
A generic list of ModelItem objects.

This associates a ModelItem class with a model and a base path in that model.
All elements in this list are subdirectories of the base path, and will be
instantiated/created/listed using methods in the ModelItem class.

This is used for ModelItem children of a ModelItem object (NOT Property
children).
=end
  class ModelItemList
    include Enumerable

    def initialize(cls, model, path)
      @item_class = cls
      @model = model
      @base_path = path
    end

=begin rdoc
List ModelItem class instances contained in this list.

Note: This always returns a sorted list.
=end
    def keys
      @item_class.list_in_path(@model, @base_path)
    end

=begin rdoc
Return number of items in list.
=end
    def count
      keys.count
    end

=begin rdoc
Return first item list.
=end
    def first
      keys.first 
    end

=begin rdoc
Return last item list.
=end
    def last
      keys.last
    end

=begin rdoc
Yield each ident in list.

See keys.
=end
    def each
      keys.each { |key| yield key }
    end

=begin rdoc
Return instance of ModelItem class for 'ident'.
=end
    def [](ident)
      @item_class.new(@model, @item_class.instance_path(@base_path, ident))
    end

=begin rdoc
Add an instance of ModelItem class to 'parent' based on 'args'.

Note: This calls ModelItemClass.create, so args must be a suitable Hash. When
a ProxyModelItemClass is used as the item class, the args will be passed to
ProxyModelItemClass.create.
=end
    def add(parent, args)
      @item_class.create(parent, args)
    end

=begin rdoc
Delete instance of ModelItem from list.

Note: this has the same effect as just calling item#delete.
=end
    def delete(ident)
      item = self[ident]
      item.delete if item
    end
  end

end
