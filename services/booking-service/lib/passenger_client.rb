require "grpc"
require_relative "aeroreserva_services_pb"
require_relative "grpc_resilience"

class PassengerClient
  def initialize(stub: nil, resilience: nil, address: ENV.fetch("PASSENGER_SERVICE_ADDR", "localhost:50052"))
    @resilience = resilience || GrpcResilience.new(dependency: "pasajeros")
    unless stub
      channel = GRPC::Core::Channel.new(address, {}, :this_channel_is_insecure)
      @connected = -> { channel.connectivity_state == GRPC::Core::ConnectivityStates::READY }
      stub = Aeroreserva::V1::PassengerService::Stub.new(address, :this_channel_is_insecure, channel_override: channel)
    end
    @stub = stub
  end

  def get_passenger(id)
    @resilience.call(operation: "GetPassenger", read: true, connected: @connected) do |deadline|
      @stub.get_passenger(Aeroreserva::V1::GetByIdRequest.new(id: id), deadline: deadline)
    end
  rescue GRPC::NotFound
    nil
  end
end
