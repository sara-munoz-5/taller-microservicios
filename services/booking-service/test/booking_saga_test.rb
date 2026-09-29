require 'minitest/autorun'
require 'stringio'
require 'ostruct'
require_relative '../lib/booking_service_impl'

class BookingSagaTest < Minitest::Test
  ID = '11111111-1111-1111-1111-111111111111'

  def setup
    @events = []
    @log = StringIO.new
    @repo = BookingRepository.new
    events = @events
    @repo.define_singleton_method(:persist_booking) { |_booking| events << :persist; raise 'simulated persistence failure' }
    @repo.define_singleton_method(:compensate_creation) { |_booking| events << :rollback }
    @flight = Object.new
    @flight.define_singleton_method(:get_flight) { |_id| OpenStruct.new(available_seats: 1) }
    @flight.define_singleton_method(:occupy_seat) { |_id| events << :occupy }
    @flight.define_singleton_method(:release_seat) { |_id| events << :release }
    @passenger = Object.new
    @passenger.define_singleton_method(:get_passenger) { |_id| true }
  end

  def run_saga
    BookingServiceImpl.new(repository: @repo, flight_client: @flight, passenger_client: @passenger, logger: @log)
      .create_booking(Aeroreserva::V1::CreateBookingRequest.new(passenger_id: ID, flight_id: ID), nil)
  end

  def test_persistence_failure_compensates_once_and_never_confirms
    assert_raises(GRPC::Internal) { run_saga }
    assert_equal [:occupy, :persist, :rollback, :release], @events
    assert_includes @log.string, 'seat_compensated'
    refute_includes @log.string, '"event":"confirmed"'
  end

  def test_ambiguous_occupy_failure_never_blindly_releases
    @flight.define_singleton_method(:occupy_seat) { |_id| raise GRPC::Unavailable.new('ambiguous') }
    assert_raises(GRPC::Unavailable) { run_saga }
    assert_empty @events
  end

  def test_failed_cleanup_still_attempts_seat_compensation
    @repo.define_singleton_method(:compensate_creation) { |_booking| raise 'database down' }
    assert_raises(GRPC::Internal) { run_saga }
    assert_equal [:occupy, :persist, :release], @events
    assert_includes @log.string, 'booking_compensation_failed'
  end

  def test_failed_compensation_logged_without_retry
    events = @events
    @flight.define_singleton_method(:release_seat) { |_id| events << :release; raise GRPC::Unavailable.new('down') }
    assert_raises(GRPC::Internal) { run_saga }
    assert_equal 1, @events.count(:release)
    assert_includes @log.string, 'seat_compensation_failed'
  end

  def test_success_persists_before_returning_confirmation
    events = @events
    @repo.define_singleton_method(:persist_booking) { |booking| events << :persist; booking }
    response = run_saga
    assert_equal :BOOKING_STATUS_CONFIRMED, response.status
    assert_equal [:occupy, :persist], @events
  end
end
