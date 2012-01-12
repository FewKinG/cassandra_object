module CassandraObject
  module Types
    class StringType < BaseType
      def encode(str)
        raise ArgumentError.new("#{self} requires a String") unless str.kind_of?(String)
	#str.encoding.to_s != "US-ASCII" ? str.dup.unpack("a*").first : str.dup
	str.dup
      end

      def wrap(record, name, value)
        value = value.to_s
        (value.frozen? ? value.dup : value).force_encoding('UTF-8')
      end

      #def decode(str)
#	str.dup
#      end
    end
  end
end
