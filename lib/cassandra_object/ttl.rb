module CassandraObject
	module TTL
		extend ActiveSupport::Concern

		included do
			class_attribute :ttl_seconds
		end

		module ClassMethods
			def ttl(seconds = nil, &block)
				if block_given?
					self.ttl_seconds = block
				else
					self.ttl_seconds = seconds
				end
			end
		end

	end
end
