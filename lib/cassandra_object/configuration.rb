module CassandraObject
  
  module Configuration
  
    CFG = YAML::load(ERB.new(IO.read(File.join(Rails.root, 'config', 'cassandra_object.yml'))).result)[Rails.env].symbolize_keys
    puts "Config loaded"
  
  end

end
