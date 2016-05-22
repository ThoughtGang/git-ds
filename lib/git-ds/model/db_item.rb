#!/usr/bin/env ruby
# :title: Git-DS::DbModelItem
=begin rdoc

Copyright 2011 Thoughtgang <http://www.thoughtgang.org>
=end

require 'git-ds/shared'
require 'git-ds/model/item'

module GitDS

# ----------------------------------------------------------------------
=begin rdoc
An in-DB ModelItem mixin. DbModelItems exist only in the database.

Note: this is an instance-method module. It should be included, not extended.
=end
  module DbModelItemObject
    include ModelItemObject
  end

# ----------------------------------------------------------------------
=begin rdoc
Note: this is a class-method module. It should be extended in a class, not 
included.
=end
  module DbModelItemClass
    include ModelItemClass

  end

# ----------------------------------------------------------------------
=begin rdoc
Base class for DB-only ModelItem objects. These do not appear in the filesystem.
=end
  class ModelItem
    extend DbModelItemClass
    include DbModelItemObject

    def initialize(model, path)
      initialize_item(model, path)
    end
  end

end
