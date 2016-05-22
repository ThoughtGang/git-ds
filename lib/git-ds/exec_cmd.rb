#!/usr/bin/env ruby
# :title: Git-DS::ExecCmd
=begin rdoc

Copyright 2010 Thoughtgang <http://www.thoughtgang.org>
=end

require 'git-ds/shared'

module GitDS

=begin rdoc
A command to be executed in a database context (i.e. an Index).

Usage:

db.exec { |idx| ... }

See also Transaction.
=end
  class ExecCmd

=begin rdoc
The GitDS::Index on which the command operates.
=end
    attr_reader :index
=begin rdoc
The GitDS::Database on which the command operates. Useful for nesting.
=end
    attr_reader :database
=begin rdoc
The message to use for the commit at the end of the command.
=end
    attr_reader :commit_msg
    DEFAULT_MESSAGE = 'auto-commit on transaction'
=begin rdoc
The Git author for the commit performed at the end of the command.
See commit_msg.
=end
    attr_reader :commit_author
=begin rdoc
The body of the command. 
=end
    attr_reader :block
=begin rdoc
Is command nested (inside a parent)?
If true, a write and commit will not be performed.
=end
    attr_reader :nested

    def initialize(index, nested, msg=DEFAULT_MESSAGE, &block)
      @index = index
      @database = index.repo
      @nested = nested
      @block = block
      # Default to no commit
      @commit_msg = msg
      # Default to config[user.name] and config[user.email]
      @commit_author = nil
    end

=begin rdoc
Set a commit message for this command.
=end
    def message(str)
      @commit_msg = str
    end

=begin rdoc
Set the Git Author info for the commit. By default, this information
is pulled from the Git config file.
=end
    def author(name, email)
      @commit_author = Grit::Actor.new(name, email)
    end

=begin rdoc
Set actor for commit.
=end
    def actor=(actor)
      @commit_author = actor
    end

=begin rdoc
Commit index.
=end
    def commit
      self.index.commit(@commit_msg, @commit_author)
    end

=begin rdoc
Perform command.
=end
    def perform
      rv = instance_eval(&self.block)

      self.index.build
      if not self.nested
        commit
        @database.notify
      end

      rv
    end
  end

end
