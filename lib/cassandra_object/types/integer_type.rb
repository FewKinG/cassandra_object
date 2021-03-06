module CassandraObject
  module Types
    class IntegerType < BaseType
      REGEX = /\A[-+]?\d+\Z/
      def encode(int)
        raise ArgumentError.new("#{int.inspect} is not an Integer.") unless int.kind_of?(Integer)
        int.to_s
      end

      def decode(str)
        return nil if str.empty?
        str.to_i
      end

      def wrap(record, name, value)
        value.to_i
      end
    end
  end
end
