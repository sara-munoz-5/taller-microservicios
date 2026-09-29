require 'minitest/autorun'
require 'securerandom'
require_relative '../lib/flight_service_impl'

class AtomicSeatsIntegrationTest < Minitest::Test
  def setup
    @id = Cassandra::Uuid.new(SecureRandom.uuid)
    @departure = Time.utc(2026, 12, 1, 15)
    @session = CassandraClient.session
    @session.execute(@session.prepare('INSERT INTO flights_by_id (id, flight_number, origin, destination, departure_at, arrival_at, total_capacity, available_seats) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'),
      arguments: [@id, 'TEST-LWT', 'Bogotá', 'Cali', @departure, @departure + 3600, 3, 3])
    @stub = Aeroreserva::V1::FlightService::Stub.new('localhost:50051', :this_channel_is_insecure)
    @request = Aeroreserva::V1::GetByIdRequest.new(id: @id.to_s)
    @implementation = FlightServiceImpl.new
  end

  def teardown
    # Only UUIDs freshly allocated by this test; never seed or user data.
    @session.execute("DELETE FROM flights_catalog WHERE catalog = 'ACTIVE' AND departure_at = ? AND id = ?", arguments: [@departure, @id])
    @session.execute('DELETE FROM flights_by_id WHERE id = ?', arguments: [@id])
  end

  def test_concurrent_occupations_and_releases_are_bounded
    gate = Queue.new
    threads = 12.times.map do
      Thread.new do
        gate.pop
        @stub.occupy_seat(@request, deadline: Time.now + 15)
        :occupied
      rescue GRPC::FailedPrecondition
        :full
      end
    end
    12.times { gate << true }
    results = threads.map(&:value)
    assert_equal 3, results.count(:occupied)
    assert_equal 9, results.count(:full)
    assert_equal 0, @stub.get_flight(@request).available_seats
    assert_equal 0, catalog_seats
    results = 12.times.map do
      Thread.new do
        @stub.release_seat(@request, deadline: Time.now + 15)
        :released
      rescue GRPC::FailedPrecondition
        :capacity
      end
    end.map(&:value)
    assert_equal 3, results.count(:released)
    assert_equal 9, results.count(:capacity)
    assert_equal 3, @stub.get_flight(@request).available_seats
    assert_equal 3, catalog_seats
    puts 'PASS LWT real: 12 ocupaciones / 3 cupos => 3 éxitos; 12 liberaciones => 3 éxitos'
  end

  def test_delayed_projection_cannot_overwrite_newer_seats
    @stub.occupy_seat(@request)
    stale = @implementation.send(:find_flight, @id.to_s)
    @stub.release_seat(@request)
    @implementation.send(:project_safely, stale)
    assert_equal 3, catalog_seats
  end

  def test_projection_failure_does_not_fail_committed_seat_and_list_repairs
    @implementation.define_singleton_method(:project_safely) { |_row| raise 'simulated projection failure' }
    # Create the catalog membership with complete data through the normal seed shape.
    @session.execute(@session.prepare("INSERT INTO flights_catalog (catalog, departure_at, id, flight_number, origin, destination, arrival_at, total_capacity, available_seats) VALUES ('ACTIVE', ?, ?, ?, ?, ?, ?, ?, ?)"),
      arguments: [@departure, @id, 'TEST-LWT', 'Bogotá', 'Cali', @departure + 3600, 3, 3])
    assert_equal 2, @implementation.occupy_seat(@request, nil).available_seats
    assert_equal 3, catalog_seats # projection intentionally stale
    list = @stub.list_flights(Aeroreserva::V1::Empty.new)
    assert_equal 2, list.flights.find { |flight| flight.id == @id.to_s }.available_seats
    assert_equal 2, catalog_seats
    @stub.release_seat(@request)
  end

  def catalog_seats
    @session.execute("SELECT available_seats FROM flights_catalog WHERE catalog = 'ACTIVE' AND departure_at = ? AND id = ?",
      arguments: [@departure, @id]).first['available_seats']
  end
end
