require 'minitest/autorun'
require_relative '../lib/booking_service_impl'

# Inject failure only in this test process, after the real Cassandra batch.
# No production fault switch and no write retry are introduced.
class FailedPersistenceRepository < BookingRepository
  attr_reader :attempt

  def persist_booking(booking)
    @attempt = booking
    super
    raise 'simulated error after Cassandra persisted the booking'
  end
end

class SagaIntegrationTest < Minitest::Test
  def test_real_seat_and_persisted_rows_are_compensated
    passenger_stub = Aeroreserva::V1::PassengerService::Stub.new(
      ENV.fetch('PASSENGER_SERVICE_ADDR'), :this_channel_is_insecure)
    passenger = passenger_stub.create_passenger(Aeroreserva::V1::CreatePassengerRequest.new(
      document_type: 'CC', document_number: "SAGA#{SecureRandom.hex(8)}",
      full_name: 'Prueba Saga', email: 'saga@example.test'), deadline: Time.now + 5)
    flight_stub = Aeroreserva::V1::FlightService::Stub.new(
      ENV.fetch('FLIGHT_SERVICE_ADDR'), :this_channel_is_insecure)
    flight = flight_stub.list_flights(Aeroreserva::V1::Empty.new, deadline: Time.now + 5).flights.find { |f| f.available_seats > 0 }
    refute_nil flight
    repository = FailedPersistenceRepository.new
    service = BookingServiceImpl.new(repository: repository)
    assert_raises(GRPC::Internal) do
      service.create_booking(Aeroreserva::V1::CreateBookingRequest.new(passenger_id: passenger.id, flight_id: flight.id), nil)
    end
    after = flight_stub.get_flight(Aeroreserva::V1::GetByIdRequest.new(id: flight.id), deadline: Time.now + 5)
    assert_equal flight.available_seats, after.available_seats
    booking = repository.find_by_id(repository.attempt['id'].to_s)
    assert_equal 'CANCELLED', booking['status']
    assert_equal ['CANCELLED'], repository.list_by_passenger(passenger.id).map { |row| row['status'] }
    old_projection = CassandraClient.session.execute(
      'SELECT id FROM bookings_by_status WHERE status = ? AND created_at = ? AND id = ?',
      arguments: ['CONFIRMED', booking['created_at'], booking['id']]).first
    assert_nil old_projection
    puts "PASS saga real: #{booking['booking_code']} cancelada y cupo restaurado"
  end
end
