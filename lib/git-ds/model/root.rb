#!/usr/bin/env ruby
# :title: Git-DS::RootItem
=begin rdoc

Copyright 2011 Thoughtgang <http://www.thoughtgang.org>
=end

require 'git-ds/shared'
require 'git-ds/model/item'

module GitDS

=begin rdoc
A mock ModelItem that acts as the root of the data model.
=end
  class RootItem
    attr_reader :model
    attr_reader :path

    def initialize(model)
      @path = ''
      @model = model
    end

    def delete
      # nop
    end

    def self.name
      ''
    end

    def self.path
      ''
    end

    def self.create(parent, args)
      return @model.root
    end

    def self.list
      return []
    end

  end
end
