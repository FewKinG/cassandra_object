require 'active_support/all'
require 'active_model'

module CassandraObject
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :Connection
  autoload :AttributeMethods
  autoload :BelongsTo
  autoload :Consistency
  autoload :Persistence
  autoload :Callbacks
  autoload :Validations
  autoload :Identity
  autoload :Inspect
  autoload :Serialization
  autoload :Migrations
  autoload :Collection
  autoload :Mocking
  autoload :Batches
  autoload :FinderMethods
  autoload :Savepoints
  autoload :Timestamps
  autoload :Type
  autoload :Schema
  autoload :Indices
	autoload :Polymorphism
	autoload :TTL
  autoload :Configuration

  module Validators
    extend ActiveSupport::Autoload

    autoload :KeyValidator
  end

  module BelongsTo
    extend ActiveSupport::Autoload

    autoload :Association
    autoload :Builder
    autoload :Reflection
  end

  module AttributeMethods
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Definition
      autoload :Dirty
      autoload :PrimaryKey
      autoload :Typecasting
    end
  end

  module Tasks
    extend ActiveSupport::Autoload
    autoload :Keyspace
    autoload :ColumnFamily
  end

  module Types
    extend ActiveSupport::Autoload
    
    autoload :BaseType
    autoload :ArrayType
    autoload :BooleanType
    autoload :DateType
    autoload :FloatType
    autoload :IntegerType
    autoload :JsonType
    autoload :StringType
    autoload :TimeType
  end
end

require 'cassandra_object/railtie' if defined?(Rails)
