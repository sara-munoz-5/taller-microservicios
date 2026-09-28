require 'minitest/autorun'
require 'securerandom'
require_relative '../lib/booking_service_impl'

# Two simultaneous cancellations of one booking (double click, two tabs) must
# release exactly one seat. A second active booking keeps the flight below its
# capacity, otherwise the capacity check would hide a double release.
class CancelRaceIntegrationTest < Minitest::Test
  V = Aeroreserva::V1

  def test_concurrent_cancellations_release_one_seat
    passengers = V::PassengerService::Stub.new(ENV.fetch('PASSENGER_SERVICE_ADDR'), :this_channel_is_insecure)
    flights = V::FlightService::Stub.new(ENV.fetch('FLIGHT_SERVICE_ADDR'), :this_channel_is_insecure)
    passenger = passengers.create_passenger(V::CreatePassengerRequest.new(
      document_type: 'CC', document_number: "RACE#{SecureRandom.hex(8)}",
      full_name: 'Prueba Cancelacion', email: 'race@example.test'), deadline: Time.now + 5)
    flight = flights.list_flights(V::Empty.new, deadline: Time.now + 5).flights.find { |f| f.available_seats > 1 }
    refute_nil flight
    seats = -> { flights.get_flight(V::GetByIdRequest.new(id: flight.id), deadline: Time.now + 5).available_seats }
    service = BookingServiceImpl.new(logger: StringIO.new)
    create = -> { service.create_booking(V::CreateBookingRequest.new(passenger_id: passenger.id, flight_id: flight.id), nil) }

    other = create.call
    before = seats.call
    target = create.call
    results = Array.new(2) do
      Thread.new do
        service.cancel_booking(V::GetByIdRequest.new(id: target.id), nil)
        :ok
      rescue GRPC::FailedPrecondition
        :already_cancelled
      end
    end.map(&:value)

    assert_equal [:already_cancelled, :ok], results.sort
    assert_equal before, seats.call
    assert_equal 'CANCELLED', BookingRepository.new.find_by_id(target.id)['status']
    service.cancel_booking(V::GetByIdRequest.new(id: other.id), nil)
    puts "PASS cancelacion concurrente: #{target.booking_code} libero un solo cupo"
  end
end
