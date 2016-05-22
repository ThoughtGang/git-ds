#!/usr/bin/env ruby
# :title: Git-DS::Transaction
=begin rdoc

Copyright 2010 Thoughtgang <http://www.thoughtgang.org>
=end

require 'git-ds/shared'
require 'git-ds/exec_cmd'

module GitDS

=begin rdoc
Exception raised to rollback a transaction.
=end
  class TransactionRollback < RuntimeError
  end

=begin rdoc
A Transaction takes a code block and guarantees that all of its commands, or
none, are executed. Transactions can be nested.

Usage:
   db.transaction { |trans, idx| ... }
=end
  class Transaction < ExecCmd

    attr_reader :propagate_exceptions

=begin rdoc
A transaction is considered successful if the transaction block executes with
no exceptions. If a block must exit prematurely and abort the transaction,
it should use the rollback method.

Note that exceptions are propagated to the parent if transaction is nested;
this permits an inner transaction to abort an outer transaction when
rollback() is called.
=end
    def perform
      @propagate_exceptions = false # propagation off by default

      return perform_top_level if not self.nested

      instance_eval(&self.block)
      index.build 

      true
    end

=begin rdoc
Throw all non-rollback exceptions after aborting the transaction. This is
useful for debugging transaction blocks.

By default, all exceptions are caught and discarded.
=end
    def propagate
      @propagate_exceptions = true
    end

=begin rdoc
Abort the transaction.
=end
    def rollback
      raise TransactionRollback.new
    end

=begin rdoc
Overrides ExecCmd#index accessor as the Transaction index will change if
batch mode is used.
=end
    def index
      database.index
    end

    private

=begin rdoc
Top-level transactions are performed in batch mode to speed things up.
=end
    def perform_top_level
      @propagate_exceptions = true
      rv = true

      begin
        xact = self
        database.batch do
          xact.instance_eval(&xact.block)
        end

        commit
        @database.notify
      rescue Exception => e
        raise e if (not e.kind_of? TransactionRollback) && @propagate_exceptions
        rv = false
      end

      rv
    end

  end
end
