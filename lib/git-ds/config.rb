#!/usr/bin/env ruby
# :title: Git-DS::RepoConfig
=begin rdoc

Copyright 2011 Thoughtgang <http://www.thoughtgang.org>
=end

module GitDS

=begin rdoc
Provides access to the repo .git/config file as a hash.

Note that this limits access to a specific section of the config file,
named by the parameter 'section'.
=end
  class RepoConfig

    def initialize(db, section='misc')
      @db = db
      @section = clean(section)
    end

=begin rdoc
Clean key so it is a valid Config token
=end
    def clean(str)
      str.gsub(/[^-[:alnum:]]/, '-')
    end

=begin rdoc
Return the full path to the variable for 'key'.
=end
    def path(key)
      @section + '.' + clean(key)
    end

=begin rdoc
Return the String value of the variable 'key'.
=end
    def [](key)
      rv = @db.repo_config[path(key)]
      rv ? rv : ''
    end

=begin rdoc
Writes the String representation of 'value' to the variable 'key'.
=end
    def []=(key, value)
      @db.repo_config[path(key)] = value.to_s
    end
  end

end
