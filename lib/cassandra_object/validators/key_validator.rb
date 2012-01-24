module CassandraObject

  module Validators

    class KeyValidator < ActiveModel::EachValidator

      def validate_each(record, attribute, value)
	if value.to_s.blank?
	  record.errors.add attribute, (options[:message] || "can't be blank")
	else
	  record.errors.add attribute, (options[:message] || "has already been taken") if record.new_record? and record.class.connection.exists?(record.class.column_family, value.to_s)
	end
      end

    end

  end

end
