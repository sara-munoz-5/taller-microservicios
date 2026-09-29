require "grpc"
require_relative "aeroreserva_services_pb"
require_relative "grpc_resilience"

class FlightClient
  def initialize(stub: nil, resilience: nil, address: ENV.fetch("FLIGHT_SERVICE_ADDR", "localhost:50051"))
    @resilience = resilience || GrpcResilience.new(dependency: "vuelos")
    unless stub
      # Own the channel so the resilience layer can tell whether a deadline
      # expired before the request was ever sent.
      channel = GRPC::Core::Channel.new(address, {}, :this_channel_is_insecure)
      @connected = -> { channel.connectivity_state == GRPC::Core::ConnectivityStates::READY }
      stub = Aeroreserva::V1::FlightService::Stub.new(address, :this_channel_is_insecure, channel_override: channel)
    end
    @stub = stub
  end

  def get_flight(id)
    @resilience.call(operation: "GetFlight", read: true, connected: @connected) do |deadline|
      @stub.get_flight(Aeroreserva::V1::GetByIdRequest.new(id: id), deadline: deadline)
    end
  rescue GRPC::NotFound
    nil
  end

  def occupy_seat(id)
    @resilience.call(operation: "OccupySeat", connected: @connected) do |deadline|
      @stub.occupy_seat(Aeroreserva::V1::GetByIdRequest.new(id: id), deadline: deadline)
    end
  end

  def release_seat(id)
    @resilience.call(operation: "ReleaseSeat", connected: @connected) do |deadline|
      @stub.release_seat(Aeroreserva::V1::GetByIdRequest.new(id: id), deadline: deadline)
    end
  end
end
