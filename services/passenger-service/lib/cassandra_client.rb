require "sorted_set"
require "cassandra"

class CassandraClient
  def self.session
    @session ||= Cassandra
      .cluster(hosts: [ENV.fetch("CASSANDRA_HOST", "127.0.0.1")],
               retry_policy: Cassandra::Retry::Policies::Fallthrough.new,
               timeout: Float(ENV.fetch("CASSANDRA_TIMEOUT_SECONDS", "0.8")))
      .connect("aeroreserva_passengers")
  end
end
