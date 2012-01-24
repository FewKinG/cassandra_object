module CassandraObject
  class RecordInvalid < StandardError
    attr_reader :record
    def initialize(record)
      @record = record
      super("Invalid record: #{@record.errors.full_messages.to_sentence}")
    end
  end

  module Validations
    extend ActiveSupport::Concern
    include ActiveModel::Validations
    include CassandraObject::Validators
    
    included do |base|
      define_model_callbacks :validation
      define_callbacks :validate, scope: :name

      validates :key, :key => true
    end
    
    module ClassMethods 
      def create!(attributes = {})
        new(attributes).tap do |object|
          object.save!
        end
      end
    end

    def save(options={})
      run_callbacks :validation do
        perform_validations(options) ? super : false
      end
    end
    
    def save!
      save || raise(RecordInvalid.new(self))
    end

    protected
      def perform_validations(options={})
        (options[:validate] != false) ? valid? : true
      end
  end
end
