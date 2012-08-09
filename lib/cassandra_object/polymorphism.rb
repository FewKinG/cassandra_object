module CassandraObject
	module Polymorphism
		extend ActiveSupport::Concern

		included do
			class_attribute :polymorphic
			class_attribute :polymorphic_base
			self.polymorphic = nil
		end
	
		module ClassMethods

			def polymorph(attrib)
				raise "Tried to make a model polymorphic multiple times" unless self.polymorphic_base.blank?
				string attrib
				self.polymorphic_base = self
				self.polymorphic = attrib.to_s
				before_save do
					self.send("#{polymorphic}=", self.class.name.underscore)
				end
			end

		end

	end
end
