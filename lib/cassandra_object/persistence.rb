module CassandraObject
  module Persistence
    extend ActiveSupport::Concern

    module ClassMethods
      def remove(id)
        ActiveSupport::Notifications.instrument("remove.cassandra_object", column_family: column_family, key: id) do
          connection.remove(column_family, id, consistency: thrift_write_consistency)
        end
      end

      def delete_all
        ActiveSupport::Notifications.instrument("truncate.cassandra_object", column_family: column_family) do
          connection.truncate!(column_family)
        end
      end

      def create(attributes = {})
        new(attributes).tap do |object|
          object.save
        end
      end
      
			def write(id, attributes, ttl = nil)
				nil_attributes = attributes.select{|key,value| value.nil?}
        attributes = encode_attributes(attributes)
        ActiveSupport::Notifications.instrument("insert.cassandra_object", column_family: column_family, key: id, attributes: attributes) do
          connection.insert(column_family, id, attributes, consistency: thrift_write_consistency, ttl: ttl)
          if nil_attributes.any?
						nil_attributes.each do |attribute,value|
	            connection.remove(column_family, id, attribute, consistency: thrift_write_consistency)
						end
          end          
        end
      end

      def instantiate(id, attributes)
				klass = self
				if polymorphic
					klass = attributes[polymorphic] ? attributes[polymorphic].camelcase.safe_constantize || self : self
					return nil if self != polymorphic_base and (klass != self or attributes[polymorphic].nil?)
				end
				return nil if attributes.except("schema_version").count == 0
        klass.allocate.tap do |object|
          object.instance_variable_set("@id", id) if id
          object.instance_variable_set("@new_record", false)
          object.instance_variable_set("@destroyed", false)
          object.instance_variable_set("@attributes", typecast_attributes(object, attributes))
					object.run_callbacks :initialize
        end
      end

      def encode_attributes(attributes)
        encoded = {}
        attributes.each do |column_name, value|
          # The ruby thrift gem expects all strings to be encoded as ascii-8bit.
          unless value.nil?
            encoded[column_name.to_s] = attribute_definitions[column_name.to_sym].coder.encode(value).force_encoding('ASCII-8BIT')
					end
        end
        encoded
      end

      def typecast_attributes(object, attributes)
        attributes = attributes.symbolize_keys
        Hash[object.class.attribute_definitions.map { |k, attribute_definition| [k.to_s, attribute_definition.instantiate(object, attributes[k])] }]
      end
    end

    def new_record?
      @new_record
    end

    def destroyed?
      @destroyed
    end

    def persisted?
      !(new_record? || destroyed?)
    end

    def save(*)
      new_record? ? create : update
    end

    def destroy
      self.class.remove(id)
      @destroyed = true
      freeze
    end

    def update_attribute(name, value)
      name = name.to_s
      send("#{name}=", value)
      save(validate: false)
    end

    def update_attributes(attributes)
			self.assign_attributes(attributes)
      save
    end

    def update_attributes!(attributes)
			self.assign_attributes(attributes)
      save!
    end

    def reload
      @attributes.update(self.class.find(id).instance_variable_get('@attributes'))
    end

    private
      def update
        write
      end

      def create
        @new_record = false
        write
      end

      def write
        changed_attributes = Hash[changed.map { |attr| [attr, read_attribute(attr)] }]
				ttl = self.class.ttl_seconds.kind_of?(Proc) ? instance_eval(&(self.class.ttl_seconds)) : self.class.ttl_seconds
        self.class.write(id, changed_attributes, ttl)
      end
  end
end
