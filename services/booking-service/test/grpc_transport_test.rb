require 'minitest/autorun'
require 'stringio'
require_relative '../lib/flight_client'

class ResilienceFlightFixture < Aeroreserva::V1::FlightService::Service
  attr_accessor :mode
  attr_reader :calls

  def initialize
    @calls, @mode = 0, :down
  end

  def get_flight(_request, _call)
    @calls += 1
    raise GRPC::Unavailable.new('simulated outage') if @mode == :down
    sleep 0.2 if @mode == :slow
    Aeroreserva::V1::Flight.new(id: 'fixture')
  end
  alias release_seat get_flight
end

class GrpcTransportTest < Minitest::Test
  def setup
    @fixture = ResilienceFlightFixture.new
    @server = GRPC::RpcServer.new
    port = @server.add_http2_port('127.0.0.1:0', :this_port_is_insecure)
    @server.handle(@fixture)
    @thread = Thread.new { @server.run }
    @server.wait_till_running
    @address = "127.0.0.1:#{port}"
    @stub = Aeroreserva::V1::FlightService::Stub.new(@address, :this_channel_is_insecure)
  end

  def teardown
    @server.stop
    @thread.join
  end

  def test_real_grpc_open_rejection_and_recovery
    now = 0
    resilience = GrpcResilience.new(dependency: 'fixture', threshold: 2, recovery: 5,
      retries: 1, retry_delay: 0, clock: -> { now })
    client = FlightClient.new(stub: @stub, resilience: resilience)
    assert_raises(GRPC::Unavailable) { client.get_flight('fixture') }
    assert_equal 2, @fixture.calls
    assert_raises(GRPC::Unavailable) { client.get_flight('fixture') }
    assert_equal 2, @fixture.calls, 'no network call while open'
    now = 5
    @fixture.mode = :healthy
    assert_equal 'fixture', client.get_flight('fixture').id
    assert_equal 3, @fixture.calls
  end

  def test_real_deadline_is_enforced
    @fixture.mode = :slow
    resilience = GrpcResilience.new(dependency: 'fixture', timeout: 0.03, retries: 0)
    client = FlightClient.new(stub: @stub, resilience: resilience)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    assert_raises(GRPC::Unavailable) { client.get_flight('fixture') }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    assert_operator elapsed, :<, 0.18
    assert_equal 1, @fixture.calls
  end

  # A stopped container is unresolvable: gRPC waits for a connection until the
  # deadline. The request never left, so it must not look ambiguous.
  def test_deadline_before_connecting_is_not_attempted
    resilience = GrpcResilience.new(dependency: 'fixture', timeout: 0.3, retries: 0, logger: StringIO.new)
    client = FlightClient.new(resilience: resilience, address: 'flight-service-stopped.invalid:50051')
    assert_raises(GrpcResilience::NotAttempted) { client.release_seat('fixture') }
  end

  def test_deadline_after_connecting_is_ambiguous
    resilience = GrpcResilience.new(dependency: 'fixture', timeout: 1, retries: 0, logger: StringIO.new)
    client = FlightClient.new(resilience: resilience, address: @address)
    @fixture.mode = :healthy
    client.release_seat('fixture') # connect the channel
    @fixture.mode = :slow
    resilience = GrpcResilience.new(dependency: 'fixture', timeout: 0.03, retries: 0, logger: StringIO.new)
    client.instance_variable_set(:@resilience, resilience)
    error = assert_raises(GRPC::Unavailable) { client.release_seat('fixture') }
    refute_kind_of GrpcResilience::NotAttempted, error, 'the server received the request'
    assert_equal 2, @fixture.calls
  end
end
