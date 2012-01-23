module CassandraObject
  
  module Configuration
  
    mattr_accessor :batch_size
    mattr_accessor :keys_at_once
    mattr_accessor :key_count
    self.batch_size = 500
    self.keys_at_once = 50
    self.key_count = 500
  
  end

end
