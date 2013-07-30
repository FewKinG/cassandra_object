module CassandraObject
  module FinderMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def find(id)
        if id.blank?
          raise CassandraObject::RecordNotFound, "Couldn't find #{self.name} with key #{id.inspect}"
        elsif attributes = connection.get(column_family, id, {:count => CassandraObject::Configuration::CFG[:key_count]}).presence
          instantiate(id, attributes)
        else
          raise CassandraObject::RecordNotFound
        end
      end

      def find_by_id(id)
        find(id)
      rescue CassandraObject::RecordNotFound
        nil
      end

      def all(options = {})
        limit = options[:limit] || 100
        results = ActiveSupport::Notifications.instrument("get_range.cassandra_object", column_family: column_family, key_count: limit) do
          connection.get_range(column_family, key_count: limit, consistency: thrift_read_consistency, count: CassandraObject::Configuration::CFG[:key_count], :batch_size => CassandraObject::Configuration::CFG[:batch_size])
        end

        results.map do |k, v|
          v.empty? ? nil : instantiate(k, v)
        end.compact
      end

      def first(options = {})
        all(options.merge(limit: 1)).first
      end

      def find_with_ids(*ids)
        ids = ids.flatten
        return ids if ids.empty?

        ids = ids.compact.map(&:to_s).uniq

				ids.each_slice(CassandraObject::Configuration::CFG[:key_count]).to_a.map do |slice|
	        multi_get(slice).values.compact
				end.flatten
      end

      def count
        connection.count_range(column_family)
      end

      def multi_get(keys, options={})
        attribute_results = ActiveSupport::Notifications.instrument("multi_get.cassandra_object", column_family: column_family, keys: keys) do
          connection.multi_get(column_family, keys.map(&:to_s), consistency: thrift_read_consistency, count: CassandraObject::Configuration::CFG[:key_count], :batch_size => CassandraObject::Configuration::CFG[:batch_size], :keys_at_once => CassandraObject::Configuration::CFG[:keys_at_once])
        end

        Hash[attribute_results.map do |key, attributes|
          [key, attributes.present? ? instantiate(key, attributes) : nil]
        end]
      end
    end
  end
end
