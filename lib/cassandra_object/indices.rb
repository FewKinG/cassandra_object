module CassandraObject
  module Indices
    extend ActiveSupport::Concern

    included do |base|
      base.class_eval do
        class_attribute :indices, :instance_writer => false
	def self.indices
	  @indices ||= {}
	end
      end
    end

    def save
      if super
	create_index_entry unless self.class.indices.blank?
	true
      else
	false
      end
    end

    def remove
      destroy_index_entry if super and not self.class.indices.blank?
    end

    def drop_index_info(col_family = nil)
      ind_ind_cf = "#{self.class.to_s}Indices"
      self.class.connection.remove(ind_ind_cf, key.to_s, (col_family.nil? ? nil : col_family.to_s))
    end

    def load_index_info(col_family = nil)
      ind_ind_cf = "#{self.class.to_s}Indices"
      data = self.class.connection.get(ind_ind_cf, key.to_s, (col_family.nil? ? nil : col_family.to_s))
      if col_family
	Marshal.load(data)
      else
	index_info = {}
	data.each do |k,v|
	  index_info[k] = Marshal.load(v)
	end
	index_info
      end
    end

    def write_index_info(col_family, key, sup_col, column, entry_id)
      ind_ind_cf = "#{self.class.to_s}Indices"
      ind_ind_entry = Marshal.dump({
	:key => key,
	:sup_col => sup_col,
	:column => column,
	:entry_id => entry_id
      }).to_s
      self.class.connection.insert(ind_ind_cf, self.key.to_s, {col_family.to_s => ind_ind_entry})
    end

    #indices << {:key => key, :sup_col => sup_col, :column_attr => column_attr}
    def create_index_entry
      destroy_index_entry
      self.class.indices.each do |k,index|
	# Create index data
	data = {}
	data[:key] = key.to_s
	if index[:block]
	  data = index[:block].call(self).merge(data)
	end

	# Set index family parameters
	column_attr = (attributes[index[:column_attr].to_s] || self.send(index[:column_attr].to_s)).to_s
	col_family = "#{self.class.to_s}Index#{k.to_s.camelcase}"
	key = index[:key].nil? ? SimpleUUID::UUID.new.to_s : (attributes[index[:key].to_s] || self.send(index[:key].to_s)).to_s
	sup_col = index[:sup_col].nil? ? nil : (attributes[index[:sup_col].to_s] || self.send(index[:sup_col].to_s)).to_s

	# Handle possible ambigous index entries
	if index[:key]
	  # Load existing index entry
	  oldentry = if sup_col
		       self.class.connection.get(col_family, key, sup_col, column_attr)
		     else
		       self.class.connection.get(col_family, key, column_attr)
		     end
	  oldentry = oldentry.nil? ? {} : Marshal.load(oldentry)

	  # Append new entry
	  entry_id = SimpleUUID::UUID.new.to_s
	  oldentry[entry_id] = data
	  entry = {column_attr => Marshal.dump(oldentry)}
	else
	  # Just create new entry
	  entry_id = nil
	  entry = {column_attr => Marshal.dump(data)}
	end

	# Save index entry
	if sup_col
	  self.class.connection.insert(col_family, key, {sup_col => entry})
	else
	  self.class.connection.insert(col_family, key, entry)
	end

	# Store index metainfo
	write_index_info col_family, key, sup_col, column_attr, entry_id
      end 
    end

    def destroy_index_entry
      metadata = load_index_info
      metadata.each do |k,v|
	index_cf = k.to_sym
	key = v[:key]
	column = v[:column]
	sup_column = v[:sup_col]
	entry_id = v[:entry_id]

	req_sup_col, req_col = (sup_column ? [sup_column, column] : [column, nil])
	if entry_id
	  data = self.class.connection.get(index_cf, key, req_sup_col, req_col)
	  next unless data
	  data = Marshal.load(data)
	  data.delete(entry_id)
	  data = (data.empty? ? nil : Marshal.dump(data))
	  if data.nil?
	    self.class.connection.remove(index_cf, key, req_sup_col, req_col)
	  else
	    if sup_column
	      self.class.connection.insert(index_cf, key, sup_column, {column => data})
	    else
	      self.class.connection.insert(index_cf, key, {column => data})
	    end
	  end
	else
	  self.class.connection.remove index_cf, key, req_sup_col, req_col
	end
      end 
      drop_index_info
    end

    module ClassMethods

      def delete_all
	super
	indices.keys.each do |index|
	  connection.clear_column_family!("#{self.to_s}Index#{index.to_s.camelcase}")
	end
	connection.clear_column_family!("#{self.to_s}Indices") unless indices.empty?
      end

      def encode(key, value = nil)
	attribute_definitions[key].coder.encode (value || attributes[key])
      end

      def decode(key, value)
	attribute_definitions[key].coder.decode(value)
      end

      def recreate_index_entries
	indices.keys.each do |index|
	  connection.clear_column_family!("#{self.to_s}Index#{index.to_s.camelcase}")
	end
	connection.clear_column_family!("#{self.to_s}Indices") unless indices.empty?
	self.find_in_batches do |ents|
	  ents.each do |ent|
	    ent.save
	  end
	end
      end

      #index_on :latitude, :group_by => :sector, :sub_group => :longitude
      # by_index :latitude, :sector => "0/0", :longitude => {:from => 0.1, :to => 0.2},
      # by_index :latitude, :sector => ["0/0", "0/1"], :longitude => 0.1, :latitude => {:from => ...
      #
      # by_index :latitude, :longitude => 0.1, :latitude => {:from => ...
      # by_index :latitude, :longitude => {:from => ...} ...
      # by_index :name, :name => "Blah"
      # by_index :name, :name => {:from => "blah", :to => "Blubb"}
      # @indices << {index_key => {:key => key, :sup_col => sup_col, :column_attr => column_attr}}
      def by_index(index_name, options = {})
	puts "Search by range"
	time = Time.now
	index = self.indices[index_name]
	raise "Index #{index_name} not existant" unless index
	family_name = "#{self.to_s}Index#{index_name.to_s.camelcase}"
	key = index[:key].nil? ? nil : options[index[:key]]
	sup_col = index[:sup_col].nil? ? nil : options[index[:sup_col]]      
	column_attr = options[index[:column_attr]]
	count = options[:count]

	if index[:sup_col]
	  if sup_col.is_a? Hash
	    start = encode(index[:sup_col], sup_col[:from])
	    finish = encode(index[:sup_col], sup_col[:to])
	  elsif sup_col
	    start = finish = encode(index[:sup_col], sup_col)
	  else
	    start = finish = nil
	  end
	  coder = attribute_definitions[index[:sup_col]].coder
	else
	  if column_attr.is_a? Hash
	    start = encode(index[:column_attr], column_attr[:from])
	    finish = encode(index[:column_attr], column_attr[:to])
	  elsif column_attr
	    start = finish = encode(index[:column_attr], column_attr)
	  else
	    start = finish = nil
	  end
	  coder = attribute_definitions[index[:column_attr]].coder
	end

	puts "Before request: #{Time.now - time}"
	if key
	  # Perform multi_get
	  unless key.is_a? Array
	    key = [key]
	  end
	  puts "Performing multi_get"
	  result = connection.multi_get(family_name, key, :start => start, :finish => finish, :batch_size => 50, :coder => coder, :keys_at_once => 1000, :count => nil, :no_hash_return => true).values.compact
	else
	  # Perform get_range over all keys
	  puts "Performing get_range"
	  result = connection.get_range(family_name, :start => start, :finish => finish, :key_count => count, :batch_size => 50).values.compact
	end

	puts "After request: #{Time.now - time}"
	if index[:sup_col]
	  if column_attr.is_a? Hash
	    start = column_attr[:from]
	    finish = column_attr[:to]
	  elsif column_attr
	    start = finish = column_attr
	  else
	    start = finish = nil
	  end
	  result = result.collect(&:values).flatten
	end

	puts "Got #{result.count} results"

	puts "Until manual filtering: #{Time.now - time}" 
	if start	      
	  puts "Perform manual filtering"
	  result.reject!{|entry| (start and decode(index[:column_attr], entry.keys.first) < start) or (finish and unpack(index[:column_attr], entry.keys.first) > finish)}
	end

	puts "After manual filtering: #{Time.now - time}"
	if options[:index_data_only]
	  result.inject({}) do |hash,v|
	    ([hash] + v.values.collect{|val| Marshal.load(val)}).inject(:merge)
	  end
	else
	  result_keys = result.collect do |r| 
	    r.values.collect do |val|
	      Marshal.load(val).values.collect{|v| v[:key]}
	    end
	  end.flatten.compact
	  multi_get(result_keys, :keys_at_once => 1000, :batch_size => 30)
	end
      end

      def index_on(index_key, options = {}, &block)
	key = options[:group_by]
	sup_col = options[:sub_group]
	column_attr = index_key
	#raise "Index attribute #{index_key} does not exist in #{self.to_s}" unless self.method_defined? column_attr
	#raise "Index subgroup #{sup_col} does not exist in #{self.to_s}" unless sup_col.nil? or self.method_defined? sup_col
	#raise "Index group #{key} does not exist in #{self.to_s}" unless key.nil? or self.method_defined? key
	validates(index_key, :presence => true)
	validates(key, :presence => true) if key
	validates(sup_col, :presence => true) if sup_col
	index_name = options[:name] || index_key
	self.indices[index_name] = {:key => key, :sup_col => sup_col, :column_attr => column_attr}
	if block_given?
	  self.indices[index_name][:block] = block
	end
      end
    end
  end
end
