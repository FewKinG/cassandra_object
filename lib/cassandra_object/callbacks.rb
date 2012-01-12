module CassandraObject
  module Callbacks
    extend ActiveSupport::Concern

    included do
      extend ActiveModel::Callbacks
      define_model_callbacks :save, :create, :update, :destroy
      define_model_callbacks :initialize, :only => :after
    end

    def destroy #:nodoc:
      _run_destroy_callbacks { super }
    end

    def initialize(*args)
      super(*args)
      run_callbacks :initialize
    end

    private
      def create_or_update #:nodoc:
        _run_save_callbacks { super }
      end

      def create #:nodoc:
        _run_create_callbacks { super }
      end

      def update(*) #:nodoc:
        _run_update_callbacks { super }
      end
  end
end
