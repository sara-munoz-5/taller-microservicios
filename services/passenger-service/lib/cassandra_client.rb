require "sorted_set"
require "cassandra"

class CassandraClient
  def self.session
    @session ||= Cassandra
      .cluster(hosts: [ENV.fetch("CASSANDRA_HOST", "127.0.0.1")])
      .connect("aeroreserva_passengers")
  end
end
