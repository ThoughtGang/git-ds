#!/usr/bin/env ruby
# :title: Git-DS::FsModelItem
=begin rdoc

Copyright 2011 Thoughtgang <http://www.thoughtgang.org>
=end

require 'git-ds/shared'
require 'git-ds/model/item'

module GitDS

# ----------------------------------------------------------------------
=begin rdoc
A filesystem ModelItem mixin. FsModelItems exist both on the filesystem and 
in the database.

Note: this is an instance-method module. It should be included, not extended.
=end
  module FsModelItemObject
    include ModelItemObject
  end

# ----------------------------------------------------------------------
=begin rdoc
Note: this is a class-method module. It should be extended in a class, not 
included.
=end
  module FsModelItemClass
    include ModelItemClass

=begin rdoc
Define a property for this ModelItem class. The property will exist in the
DB and on the filesystem.
=end
    def property(name, default=0, &block)
      define_fs_property(name, default, &block)
    end

  end

# ----------------------------------------------------------------------
=begin rdoc
Base class for filesystem ModelItem objects.
=end
  class FsModelItem
    extend FsModelItemClass
    include FsModelItemObject

    def initialize(model, path)
      initialize_item(model, path)
    end
  end

end
