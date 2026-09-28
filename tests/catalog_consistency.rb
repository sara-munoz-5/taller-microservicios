# Ejecutar dentro de flight-service; solo consulta su propio keyspace.
require_relative '/app/lib/cassandra_client'
session = CassandraClient.session
catalog = session.execute("SELECT * FROM flights_catalog WHERE catalog = 'ACTIVE'").to_a
raise 'Expected 9 flights' unless catalog.length == 9
catalog.each do |flight|
  row = session.execute('SELECT * FROM flights_by_id WHERE id = ?', arguments: [flight['id']]).first
  %w[flight_number origin destination departure_at arrival_at total_capacity available_seats].each do |key|
    raise "Mismatch: #{key}" unless row[key] == flight[key]
  end
  raise 'Invalid seats' unless (0..flight['total_capacity']).cover?(flight['available_seats'])
end
puts 'PASS: 9 vuelos coherentes en flights_by_id y flights_catalog'
