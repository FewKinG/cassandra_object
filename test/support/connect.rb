CassandraObject::Base.establish_connection(
  namespace: 'test',
  access_key_id: ENV['AWS_ACCESS_KEY_ID'],
  secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
)

# CassandraObject::Base.establish_connection(
#   keyspace: 'place_directory_development',
#   servers: '127.0.0.1:9160'
# )