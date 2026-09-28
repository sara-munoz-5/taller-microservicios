require 'minitest/autorun'
require 'stringio'
require_relative '../lib/grpc_resilience'
require_relative '../lib/flight_client'
require_relative '../lib/passenger_client'

class GrpcResilienceTest < Minitest::Test
  def setup
    @now = 0.0
    @log = StringIO.new
  end

  def breaker(**options)
    GrpcResilience.new(dependency: 'test', threshold: 2, recovery: 5, timeout: 0.1,
      retries: 1, retry_delay: 0, clock: -> { @now }, logger: @log, **options)
  end

  def test_open_reject_and_half_open_recover
    circuit = breaker
    calls = 0
    assert_raises(GRPC::Unavailable) do
      circuit.call(operation: 'GetFlight', read: true) { calls += 1; raise GRPC::Unavailable.new('down') }
    end
    assert_equal 2, calls
    assert_raises(GRPC::Unavailable) { circuit.call(operation: 'GetFlight', read: true) { calls += 1 } }
    assert_equal 2, calls, 'open circuit must not invoke gRPC'
    @now = 5
    assert_equal :ok, circuit.call(operation: 'GetFlight', read: true) { calls += 1; :ok }
    assert_equal :ok, circuit.call(operation: 'GetFlight') { :ok }
    %w[opened rejected half_open_probe recovered].each { |event| assert_includes @log.string, event }
  end

  def test_only_one_half_open_probe_and_failed_probe_reopens
    circuit = breaker(threshold: 1, retries: 0)
    assert_raises(GRPC::Unavailable) { circuit.call(operation: 'read') { raise GRPC::Unavailable.new('down') } }
    @now = 5
    entered, finish = Queue.new, Queue.new
    probe = Thread.new do
      assert_raises(GRPC::Unavailable) do
        circuit.call(operation: 'read') { entered << true; finish.pop; raise GRPC::Unavailable.new('down') }
      end
    end
    entered.pop
    assert_raises(GRPC::Unavailable) { circuit.call(operation: 'read') { flunk 'concurrent probe' } }
    finish << true
    probe.value
    assert_raises(GRPC::Unavailable) { circuit.call(operation: 'read') { flunk 'failed probe did not reopen' } }
  end

  def test_writes_never_retry_and_business_errors_do_not_open
    circuit = breaker(threshold: 1)
    calls = 0
    assert_raises(GRPC::Unavailable) do
      circuit.call(operation: 'OccupySeat') { calls += 1; raise GRPC::DeadlineExceeded.new('late') }
    end
    assert_equal 1, calls
    other = breaker(threshold: 1)
    3.times { assert_raises(GRPC::NotFound) { other.call(operation: 'read', read: true) { raise GRPC::NotFound.new('missing') } } }
    assert_equal :ok, other.call(operation: 'read') { :ok }
  end

  def test_retry_transient_read_and_explicit_deadline
    circuit = breaker(threshold: 3)
    calls = 0
    result = circuit.call(operation: 'GetFlight', read: true) do |deadline|
      assert_operator deadline, :>, Time.now
      assert_operator deadline, :<=, Time.now + 0.1
      calls += 1
      raise GRPC::DeadlineExceeded.new('late') if calls == 1
      :ok
    end
    assert_equal :ok, result
    assert_equal 2, calls
  end

  def test_late_success_does_not_close_newly_opened_circuit
    circuit = breaker(threshold: 1, retries: 0)
    entered, finish = Queue.new, Queue.new
    old = Thread.new { circuit.call(operation: 'old') { entered << true; finish.pop; :ok } }
    entered.pop
    assert_raises(GRPC::Unavailable) { circuit.call(operation: 'new') { raise GRPC::Unavailable.new('down') } }
    finish << true
    old.value
    assert_raises(GRPC::Unavailable) { circuit.call(operation: 'read') { flunk 'late success closed circuit' } }
  end

  def test_clients_have_independent_circuits_and_no_write_retries
    stub = Object.new
    calls = Hash.new(0)
    %i[get_flight occupy_seat release_seat get_passenger].each do |method|
      stub.define_singleton_method(method) do |_request, deadline:|
        calls[method] += 1
        raise GRPC::Unavailable.new('down')
      end
    end
    flights = FlightClient.new(stub: stub, resilience: breaker(threshold: 1))
    passengers = PassengerClient.new(stub: stub, resilience: breaker(threshold: 1))
    assert_raises(GRPC::Unavailable) { flights.occupy_seat('id') }
    assert_raises(GRPC::Unavailable) { flights.get_flight('id') }
    assert_equal 0, calls[:get_flight]
    assert_raises(GRPC::Unavailable) { passengers.get_passenger('id') }
    assert_equal 1, calls[:get_passenger]
    release = FlightClient.new(stub: stub, resilience: breaker(threshold: 3))
    assert_raises(GRPC::Unavailable) { release.release_seat('id') }
    assert_equal 1, calls[:release_seat]
  end
end
