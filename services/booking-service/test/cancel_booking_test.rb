require 'minitest/autorun'
require 'stringio'
require_relative '../lib/booking_service_impl'

class CancelBookingTest < Minitest::Test
  ID = '11111111-1111-1111-1111-111111111111'

  def setup
    @events = []
    @log = StringIO.new
    events = @events
    booking = { 'id' => Cassandra::Uuid.new(ID), 'booking_code' => 'RES-TEST01', 'passenger_id' => Cassandra::Uuid.new(ID),
                'flight_id' => Cassandra::Uuid.new(ID), 'created_at' => Time.now.utc, 'status' => 'CONFIRMED' }
    @repo = BookingRepository.new
    @repo.define_singleton_method(:find_by_id) { |_id| booking }
    @repo.define_singleton_method(:mark_cancelled) { |_booking| events << :mark; true }
    @repo.define_singleton_method(:revert_cancellation) { |_booking| events << :revert; true }
    @repo.define_singleton_method(:project_cancellation) { |_booking| events << :project }
    @flight = Object.new
    @flight.define_singleton_method(:release_seat) { |_id| events << :release }
  end

  def cancel
    BookingServiceImpl.new(repository: @repo, flight_client: @flight, passenger_client: Object.new, logger: @log)
      .cancel_booking(Aeroreserva::V1::GetByIdRequest.new(id: ID), nil)
  end

  def test_claims_cancellation_before_releasing_seat
    assert_equal :BOOKING_STATUS_CANCELLED, cancel.status
    assert_equal [:mark, :release, :project], @events
  end

  def test_lost_race_never_releases_a_second_seat
    events = @events
    cancelled = @repo.find_by_id(ID).merge('status' => 'CANCELLED')
    @repo.define_singleton_method(:mark_cancelled) { |_booking| events << :mark; false }
    @repo.define_singleton_method(:find_by_id) { |_id| cancelled }
    assert_raises(GRPC::FailedPrecondition) { cancel }
    refute_includes @events, :release
    assert_equal [:mark, :project], @events
  end

  def test_lost_race_does_not_mark_a_reverted_booking_as_cancelled
    events = @events
    @repo.define_singleton_method(:mark_cancelled) { |_booking| events << :mark; false }
    # find_by_id still returns CONFIRMED: the winner reverted its cancellation.
    assert_raises(GRPC::FailedPrecondition) { cancel }
    assert_equal [:mark], @events
  end

  def test_circuit_rejection_reverts_cancellation
    @flight.define_singleton_method(:release_seat) { |_id| raise GrpcResilience::NotAttempted.new('open') }
    assert_raises(GRPC::Unavailable) { cancel }
    assert_equal [:mark, :revert], @events
    assert_includes @log.string, 'cancellation_reverted'
  end

  def test_definite_rejection_reverts_cancellation
    @flight.define_singleton_method(:release_seat) { |_id| raise GRPC::FailedPrecondition.new('full') }
    assert_raises(GRPC::FailedPrecondition) { cancel }
    assert_equal [:mark, :revert], @events
  end

  def test_ambiguous_release_keeps_cancellation_and_never_reconfirms
    @flight.define_singleton_method(:release_seat) { |_id| raise GRPC::Unavailable.new('timeout') }
    assert_equal :BOOKING_STATUS_CANCELLED, cancel.status
    assert_equal [:mark, :project], @events
    assert_includes @log.string, 'seat_release_ambiguous'
  end

  def test_projection_failure_keeps_committed_cancellation
    @repo.define_singleton_method(:project_cancellation) { |_booking| raise 'database down' }
    assert_equal :BOOKING_STATUS_CANCELLED, cancel.status
    assert_includes @log.string, 'cancellation_projection_failed'
  end
end
