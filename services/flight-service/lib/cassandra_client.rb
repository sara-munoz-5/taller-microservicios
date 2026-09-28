require "sorted_set"
require "cassandra"

class CassandraClient
  PREPARE_MUTEX = Mutex.new

  def self.prepare(cql)
    PREPARE_MUTEX.synchronize do
      @statements ||= {}
      @statements[cql] ||= session.prepare(cql)
    end
  end

  def self.session
    @session ||= Cassandra
      .cluster(hosts: [ENV.fetch("CASSANDRA_HOST", "127.0.0.1")],
               retry_policy: Cassandra::Retry::Policies::Fallthrough.new,
               timeout: Float(ENV.fetch("CASSANDRA_TIMEOUT_SECONDS", "0.8")))
      .connect("aeroreserva_flights")
  end
end
